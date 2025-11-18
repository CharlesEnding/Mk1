import std/[options, paths, strformat, tables]
import xl

import ../primitives/[animation, model, mesh]
import ../utils/[blas, gltf]

template solidPattern(color: string): untyped =
  XlPattern(patternType: "solid", fgColor: XlColor(rgb: color))

proc writeJointHierarchy(sheet: XlSheet, joint: Joint, row: var int, depth: int = 0) =
  sheet[row, 0].value = joint.id
  sheet[row, 1].value = joint.name
  sheet[row, 2].value = depth
  row.inc
  for child in joint.children:
    writeJointHierarchy(sheet, child, row, depth + 1)

proc writeMatrix(sheet: XlSheet, row, startCol: int, m: Mat4) =
  var col = startCol
  for i in 0..3:
    for j in 0..3:
      sheet[row, col].value = m[i][j]
      sheet[row, col].numFmt = XlNumFmt(code: "0.000")
      col.inc

proc writeAnimTransforms(sheet: XlSheet, anim: Animation) =
  var row = 0
  sheet[row, 0].value = "JointID"
  sheet[row, 1].value = "Timestamp"
  sheet[row, 2].value = "X"
  sheet[row, 3].value = "Y"
  sheet[row, 4].value = "Z"
  row.inc
  
  for jointId, transforms in anim.translations.pairs():
    for t in transforms:
      sheet[row, 0].value = jointId
      sheet[row, 1].value = t.timestamp
      sheet[row, 1].numFmt = XlNumFmt(code: "0.000")
      sheet[row, 2].value = t.translation[0]
      sheet[row, 2].numFmt = XlNumFmt(code: "0.000")
      sheet[row, 3].value = t.translation[1]
      sheet[row, 3].numFmt = XlNumFmt(code: "0.000")
      sheet[row, 4].value = t.translation[2]
      sheet[row, 4].numFmt = XlNumFmt(code: "0.000")
      row.inc

proc writeAnimRotations(sheet: XlSheet, anim: Animation) =
  var row = 0
  sheet[row, 0].value = "JointID"
  sheet[row, 1].value = "Timestamp"
  sheet[row, 2].value = "X"
  sheet[row, 3].value = "Y"
  sheet[row, 4].value = "Z"
  sheet[row, 5].value = "W"
  row.inc
  
  for jointId, transforms in anim.rotations.pairs():
    for t in transforms:
      sheet[row, 0].value = jointId
      sheet[row, 1].value = t.timestamp
      sheet[row, 1].numFmt = XlNumFmt(code: "0.000")
      sheet[row, 2].value = t.rotation[0]
      sheet[row, 2].numFmt = XlNumFmt(code: "0.000")
      sheet[row, 3].value = t.rotation[1]
      sheet[row, 3].numFmt = XlNumFmt(code: "0.000")
      sheet[row, 4].value = t.rotation[2]
      sheet[row, 4].numFmt = XlNumFmt(code: "0.000")
      sheet[row, 5].value = t.rotation[3]
      sheet[row, 5].numFmt = XlNumFmt(code: "0.000")
      row.inc

proc writeJointMatrices(sheet: XlSheet, row: var int, j: Joint, matrices: array[MAX_NUM_JOINTS, Mat4], depth: int = 0) =
  # JointID - light blue
  sheet[row, 0].value = j.id
  sheet[row, 0].fill = XlFill(patternFill: solidPattern("DDEBF7"))
  
  # JointName - light gray for metadata
  sheet[row, 1].value = j.name
  sheet[row, 1].fill = XlFill(patternFill: solidPattern("F2F2F2"))
  
  # Matrix elements - alternate orange/white by depth
  writeMatrix(sheet, row, 2, matrices[j.id])
  if depth mod 2 == 0:
    for col in 2..17:
      sheet[row, col].fill = XlFill(patternFill: solidPattern("FCE4D6"))
  
  row.inc
  for c in j.children:
    writeJointMatrices(sheet, row, c, matrices, depth + 1)

proc writeIntermediateMatrices(sheet: XlSheet, row: var int, anim: Animation, j: Joint, time: float, parentBind, parentAnim: Mat4, depth: int = 0) =
  var localAnim = anim.interpolate(j.id, j.transform, time)
  var bindTrans = parentBind * j.transform
  var animTrans = parentAnim * localAnim
  var final = animTrans * bindTrans.inverse
  
  # JointID - light blue
  sheet[row, 0].value = j.id
  sheet[row, 0].fill = XlFill(patternFill: solidPattern("DDEBF7"))
  
  # JointName - light gray
  sheet[row, 1].value = j.name
  sheet[row, 1].fill = XlFill(patternFill: solidPattern("F2F2F2"))
  
  # Different matrix types get different colors
  writeMatrix(sheet, row, 2, j.transform)
  writeMatrix(sheet, row, 18, localAnim)
  writeMatrix(sheet, row, 34, bindTrans)
  writeMatrix(sheet, row, 50, animTrans)
  writeMatrix(sheet, row, 66, final)
  
  # Joint Transform - light cyan
  for col in 2..17:
    sheet[row, col].fill = XlFill(patternFill: solidPattern("D9EAD3"))
  
  # Local Anim Transform - light yellow
  for col in 18..33:
    sheet[row, col].fill = XlFill(patternFill: solidPattern("FFF2CC"))
  
  # Bind Transform - light orange
  for col in 34..49:
    sheet[row, col].fill = XlFill(patternFill: solidPattern("FCE4D6"))
  
  # Anim Transform - light purple
  for col in 50..65:
    sheet[row, col].fill = XlFill(patternFill: solidPattern("E4DFEC"))
  
  # Final Matrix - light pink (most important result)
  for col in 66..81:
    sheet[row, col].fill = XlFill(patternFill: solidPattern("F4CCCC"))
  
  row.inc
  
  for c in j.children:
    writeIntermediateMatrices(sheet, row, anim, c, time, bindTrans, animTrans, depth + 1)

proc writeBoneCentricData(sheet: XlSheet, row: var int, anim: Animation, j: Joint, parentBind, parentAnim: Mat4, depth: int = 0) =
  # Calculate matrices
  var localAnim = anim.interpolate(j.id, j.transform, time=0.0)
  var bindTrans = parentBind * j.transform
  var animTrans = parentAnim * localAnim
  var final = animTrans * bindTrans.inverse
  
  # Header: Joint ID and Name
  sheet[row, 0].value = &"JOINT {j.id}: {j.name}"
  var rng = sheet.range((row, 0), (row, 15))
  rng.merge()
  rng.fill = XlFill(patternFill: solidPattern("B4C7E7"))
  rng.font = XlFont(bold: true, size: 12.0)
  rng.alignment = XlAlignment(horizontal: "center")
  row.inc
  row.inc
  
  # Translation keyframes
  if anim.translations.hasKey(j.id):
    sheet[row, 0].value = "Translation Keyframes"
    sheet.row(row).fill = XlFill(patternFill: solidPattern("E2EFDA"))
    sheet.row(row).font = XlFont(bold: true)
    row.inc
    sheet[row, 0].value = "Time"
    sheet[row, 1].value = "X"
    sheet[row, 2].value = "Y"
    sheet[row, 3].value = "Z"
    sheet.row(row).fill = XlFill(patternFill: solidPattern("F2F2F2"))
    sheet.row(row).font = XlFont(bold: true)
    row.inc
    for t in anim.translations[j.id]:
      sheet[row, 0].value = t.timestamp
      sheet[row, 0].numFmt = XlNumFmt(code: "0.000")
      sheet[row, 0].fill = XlFill(patternFill: solidPattern("E4DFEC"))
      sheet[row, 1].value = t.translation[0]
      sheet[row, 1].numFmt = XlNumFmt(code: "0.000")
      sheet[row, 2].value = t.translation[1]
      sheet[row, 2].numFmt = XlNumFmt(code: "0.000")
      sheet[row, 3].value = t.translation[2]
      sheet[row, 3].numFmt = XlNumFmt(code: "0.000")
      row.inc
    row.inc
  
  # Rotation keyframes
  if anim.rotations.hasKey(j.id):
    sheet[row, 0].value = "Rotation Keyframes (Quaternion)"
    sheet.row(row).fill = XlFill(patternFill: solidPattern("FFF2CC"))
    sheet.row(row).font = XlFont(bold: true)
    row.inc
    sheet[row, 0].value = "Time"
    sheet[row, 1].value = "X"
    sheet[row, 2].value = "Y"
    sheet[row, 3].value = "Z"
    sheet[row, 4].value = "W"
    sheet.row(row).fill = XlFill(patternFill: solidPattern("F2F2F2"))
    sheet.row(row).font = XlFont(bold: true)
    row.inc
    for t in anim.rotations[j.id]:
      sheet[row, 0].value = t.timestamp
      sheet[row, 0].numFmt = XlNumFmt(code: "0.000")
      sheet[row, 0].fill = XlFill(patternFill: solidPattern("E4DFEC"))
      sheet[row, 1].value = t.rotation[0]
      sheet[row, 1].numFmt = XlNumFmt(code: "0.000")
      sheet[row, 2].value = t.rotation[1]
      sheet[row, 2].numFmt = XlNumFmt(code: "0.000")
      sheet[row, 3].value = t.rotation[2]
      sheet[row, 3].numFmt = XlNumFmt(code: "0.000")
      sheet[row, 4].value = t.rotation[3]
      sheet[row, 4].numFmt = XlNumFmt(code: "0.000")
      row.inc
    row.inc
  
  # Final state (position + quaternion)
  var finalPos = final.translationVector()
  var finalQuat = final.rotationVector()
  
  sheet[row, 0].value = "Final State (t=0)"
  sheet.row(row).fill = XlFill(patternFill: solidPattern("F4CCCC"))
  sheet.row(row).font = XlFont(bold: true)
  row.inc
  
  sheet[row, 0].value = "Position"
  sheet[row, 0].fill = XlFill(patternFill: solidPattern("F2F2F2"))
  sheet[row, 0].font = XlFont(bold: true)
  sheet[row, 1].value = finalPos[0]
  sheet[row, 1].numFmt = XlNumFmt(code: "0.000")
  sheet[row, 1].fill = XlFill(patternFill: solidPattern("E2EFDA"))
  sheet[row, 2].value = finalPos[1]
  sheet[row, 2].numFmt = XlNumFmt(code: "0.000")
  sheet[row, 2].fill = XlFill(patternFill: solidPattern("E2EFDA"))
  sheet[row, 3].value = finalPos[2]
  sheet[row, 3].numFmt = XlNumFmt(code: "0.000")
  sheet[row, 3].fill = XlFill(patternFill: solidPattern("E2EFDA"))
  row.inc
  
  sheet[row, 0].value = "Quaternion"
  sheet[row, 0].fill = XlFill(patternFill: solidPattern("F2F2F2"))
  sheet[row, 0].font = XlFont(bold: true)
  sheet[row, 1].value = finalQuat[0]
  sheet[row, 1].numFmt = XlNumFmt(code: "0.000")
  sheet[row, 1].fill = XlFill(patternFill: solidPattern("FFF2CC"))
  sheet[row, 2].value = finalQuat[1]
  sheet[row, 2].numFmt = XlNumFmt(code: "0.000")
  sheet[row, 2].fill = XlFill(patternFill: solidPattern("FFF2CC"))
  sheet[row, 3].value = finalQuat[2]
  sheet[row, 3].numFmt = XlNumFmt(code: "0.000")
  sheet[row, 3].fill = XlFill(patternFill: solidPattern("FFF2CC"))
  sheet[row, 4].value = finalQuat[3]
  sheet[row, 4].numFmt = XlNumFmt(code: "0.000")
  sheet[row, 4].fill = XlFill(patternFill: solidPattern("FFF2CC"))
  row.inc
  row.inc
  
  # Matrices in 4x4 layout
  sheet[row, 0].value = "Joint Transform (4x4)"
  sheet.row(row).fill = XlFill(patternFill: solidPattern("D9EAD3"))
  sheet.row(row).font = XlFont(bold: true)
  row.inc
  for i in 0..3:
    for k in 0..3:
      sheet[row + i, k].value = j.transform[i][k]
      sheet[row + i, k].numFmt = XlNumFmt(code: "0.000")
      sheet[row + i, k].fill = XlFill(patternFill: solidPattern("D9EAD3"))
  row += 4
  row.inc
  
  sheet[row, 0].value = "Local Anim Transform (4x4)"
  sheet.row(row).fill = XlFill(patternFill: solidPattern("FFF2CC"))
  sheet.row(row).font = XlFont(bold: true)
  row.inc
  for i in 0..3:
    for k in 0..3:
      sheet[row + i, k].value = localAnim[i][k]
      sheet[row + i, k].numFmt = XlNumFmt(code: "0.000")
      sheet[row + i, k].fill = XlFill(patternFill: solidPattern("FFF2CC"))
  row += 4
  row.inc
  
  sheet[row, 0].value = "Bind Transform (4x4)"
  sheet.row(row).fill = XlFill(patternFill: solidPattern("FCE4D6"))
  sheet.row(row).font = XlFont(bold: true)
  row.inc
  for i in 0..3:
    for k in 0..3:
      sheet[row + i, k].value = bindTrans[i][k]
      sheet[row + i, k].numFmt = XlNumFmt(code: "0.000")
      sheet[row + i, k].fill = XlFill(patternFill: solidPattern("FCE4D6"))
  row += 4
  row.inc
  
  sheet[row, 0].value = "Anim Transform (4x4)"
  sheet.row(row).fill = XlFill(patternFill: solidPattern("E4DFEC"))
  sheet.row(row).font = XlFont(bold: true)
  row.inc
  for i in 0..3:
    for k in 0..3:
      sheet[row + i, k].value = animTrans[i][k]
      sheet[row + i, k].numFmt = XlNumFmt(code: "0.000")
      sheet[row + i, k].fill = XlFill(patternFill: solidPattern("E4DFEC"))
  row += 4
  row.inc
  
  sheet[row, 0].value = "Final Matrix (4x4)"
  sheet.row(row).fill = XlFill(patternFill: solidPattern("F4CCCC"))
  sheet.row(row).font = XlFont(bold: true)
  row.inc
  for i in 0..3:
    for k in 0..3:
      sheet[row + i, k].value = final[i][k]
      sheet[row + i, k].numFmt = XlNumFmt(code: "0.000")
      sheet[row + i, k].fill = XlFill(patternFill: solidPattern("F4CCCC"))
  row += 4
  row.inc
  row.inc
  
  # Recurse to children
  for c in j.children:
    writeBoneCentricData(sheet, row, anim, c, bindTrans, animTrans, depth + 1)

when isMainModule:
  var kiteModel = gltf.loadObj[AnimatedMeshVertex]("assets/kite.glb", AnimatedMeshVertex())
  
  if kiteModel.animationComponent.isNone():
    echo "No animations found in model"
    quit(1)
  
  var animComp = kiteModel.animationComponent.get()
  var workbook = newWorkbook()
  
  # Hierarchy sheet
  var hierSheet = workbook.add("Hierarchy")
  hierSheet[0, 0].value = "JointID"
  hierSheet[0, 1].value = "JointName"
  hierSheet[0, 2].value = "Depth"
  hierSheet.row(0).fill = XlFill(patternFill: solidPattern("B4C7E7"))
  hierSheet.row(0).font = XlFont(bold: true)
  var row = 1
  writeJointHierarchy(hierSheet, animComp.skeletonRoot, row)
  
  # Process first 3 animations only
  for i in 0..<min(30, animComp.animations.len):
    var anim = animComp.animations[i]
    var animName = anim.name
    if animName.len > 31: animName = animName[0..30]
    
    var sheet = workbook.add(animName)
    row = 0
    
    # Section 1: Translations
    sheet[row, 0].value = "TRANSLATIONS"
    var rng = sheet.range((row, 0), (row, 4))
    rng.merge()
    rng.fill = XlFill(patternFill: solidPattern("C6EFCE"))
    rng.font = XlFont(bold: true, size: 12.0)
    rng.alignment = XlAlignment(horizontal: "center")
    row.inc
    
    sheet[row, 0].value = "JointID"
    sheet[row, 1].value = "Timestamp"
    sheet[row, 2].value = "X"
    sheet[row, 3].value = "Y"
    sheet[row, 4].value = "Z"
    sheet.row(row).fill = XlFill(patternFill: solidPattern("E2EFDA"))
    sheet.row(row).font = XlFont(bold: true)
    row.inc
    
    var lastJointId = -1
    var jointColor = false
    for jointId, transforms in anim.translations.pairs():
      if jointId != lastJointId:
        jointColor = not jointColor
        lastJointId = jointId
      for t in transforms:
        # JointID column - light blue to distinguish metadata
        sheet[row, 0].value = jointId
        sheet[row, 0].fill = XlFill(patternFill: solidPattern("DDEBF7"))
        
        # Timestamp column - light purple for time data
        sheet[row, 1].value = t.timestamp
        sheet[row, 1].numFmt = XlNumFmt(code: "0.000")
        sheet[row, 1].fill = XlFill(patternFill: solidPattern("E4DFEC"))
        
        # X, Y, Z columns - alternate between green/white per joint
        sheet[row, 2].value = t.translation[0]
        sheet[row, 2].numFmt = XlNumFmt(code: "0.000")
        sheet[row, 3].value = t.translation[1]
        sheet[row, 3].numFmt = XlNumFmt(code: "0.000")
        sheet[row, 4].value = t.translation[2]
        sheet[row, 4].numFmt = XlNumFmt(code: "0.000")
        if jointColor:
          sheet[row, 2].fill = XlFill(patternFill: solidPattern("E2EFDA"))
          sheet[row, 3].fill = XlFill(patternFill: solidPattern("E2EFDA"))
          sheet[row, 4].fill = XlFill(patternFill: solidPattern("E2EFDA"))
        row.inc
    
    row.inc
    
    # Section 2: Rotations
    sheet[row, 0].value = "ROTATIONS"
    rng = sheet.range((row, 0), (row, 5))
    rng.merge()
    rng.fill = XlFill(patternFill: solidPattern("FFE699"))
    rng.font = XlFont(bold: true, size: 12.0)
    rng.alignment = XlAlignment(horizontal: "center")
    row.inc
    
    sheet[row, 0].value = "JointID"
    sheet[row, 1].value = "Timestamp"
    sheet[row, 2].value = "X"
    sheet[row, 3].value = "Y"
    sheet[row, 4].value = "Z"
    sheet[row, 5].value = "W"
    sheet.row(row).fill = XlFill(patternFill: solidPattern("FFF2CC"))
    sheet.row(row).font = XlFont(bold: true)
    row.inc
    
    lastJointId = -1
    jointColor = false
    for jointId, transforms in anim.rotations.pairs():
      if jointId != lastJointId:
        jointColor = not jointColor
        lastJointId = jointId
      for t in transforms:
        # JointID column - light blue
        sheet[row, 0].value = jointId
        sheet[row, 0].fill = XlFill(patternFill: solidPattern("DDEBF7"))
        
        # Timestamp column - light purple
        sheet[row, 1].value = t.timestamp
        sheet[row, 1].numFmt = XlNumFmt(code: "0.000")
        sheet[row, 1].fill = XlFill(patternFill: solidPattern("E4DFEC"))
        
        # X, Y, Z, W columns - alternate yellow/white per joint
        sheet[row, 2].value = t.rotation[0]
        sheet[row, 2].numFmt = XlNumFmt(code: "0.000")
        sheet[row, 3].value = t.rotation[1]
        sheet[row, 3].numFmt = XlNumFmt(code: "0.000")
        sheet[row, 4].value = t.rotation[2]
        sheet[row, 4].numFmt = XlNumFmt(code: "0.000")
        sheet[row, 5].value = t.rotation[3]
        sheet[row, 5].numFmt = XlNumFmt(code: "0.000")
        if jointColor:
          sheet[row, 2].fill = XlFill(patternFill: solidPattern("FFF2CC"))
          sheet[row, 3].fill = XlFill(patternFill: solidPattern("FFF2CC"))
          sheet[row, 4].fill = XlFill(patternFill: solidPattern("FFF2CC"))
          sheet[row, 5].fill = XlFill(patternFill: solidPattern("FFF2CC"))
        row.inc
    
    row.inc
    
    # Section 3: Final Matrices at t=0
    sheet[row, 0].value = "FINAL JOINT MATRICES (t=0)"
    rng = sheet.range((row, 0), (row, 17))
    rng.merge()
    rng.fill = XlFill(patternFill: solidPattern("F4B084"))
    rng.font = XlFont(bold: true, size: 12.0)
    rng.alignment = XlAlignment(horizontal: "center")
    row.inc
    
    sheet[row, 0].value = "JointID"
    sheet[row, 1].value = "JointName"
    for k in 0..15: sheet[row, 2+k].value = &"M{k}"
    sheet.row(row).fill = XlFill(patternFill: solidPattern("FCE4D6"))
    sheet.row(row).font = XlFont(bold: true)
    row.inc
    
    var matrices: array[MAX_NUM_JOINTS, Mat4]
    anim.jointMatrices(0.0, animComp.skeletonRoot, IDENTMAT4, IDENTMAT4, matrices)
    writeJointMatrices(sheet, row, animComp.skeletonRoot, matrices)
    
    row = row + animComp.skeletonRoot.countJoints() + 1
    
    # Section 4: Intermediate Matrices at t=0
    sheet[row, 0].value = "INTERMEDIATE MATRICES (t=0)"
    rng = sheet.range((row, 0), (row, 81))
    rng.merge()
    rng.fill = XlFill(patternFill: solidPattern("D9D9D9"))
    rng.font = XlFont(bold: true, size: 12.0)
    rng.alignment = XlAlignment(horizontal: "center")
    row.inc
    
    sheet[row, 0].value = "JointID"
    sheet[row, 1].value = "Name"
    for k in 0..15: sheet[row, 2+k].value = &"JTrans{k}"
    for k in 0..15: sheet[row, 18+k].value = &"LocAnim{k}"
    for k in 0..15: sheet[row, 34+k].value = &"Bind{k}"
    for k in 0..15: sheet[row, 50+k].value = &"Anim{k}"
    for k in 0..15: sheet[row, 66+k].value = &"Final{k}"
    sheet.row(row).fill = XlFill(patternFill: solidPattern("EDEDED"))
    sheet.row(row).font = XlFont(bold: true)
    row.inc
    
    writeIntermediateMatrices(sheet, row, anim, animComp.skeletonRoot, 0.0, IDENTMAT4, IDENTMAT4)
    
    # Auto-size columns
    for col in 0..5:
      sheet.col(col).width = 12
    
    # Create second sheet: Bone-centric view
    var boneName = animName & "_Bones"
    if boneName.len > 31: boneName = animName[0..24] & "_Bones"
    var boneSheet = workbook.add(boneName)
    row = 0
    writeBoneCentricData(boneSheet, row, anim, animComp.skeletonRoot, IDENTMAT4, IDENTMAT4)
    
    # Auto-size columns for bone sheet
    for col in 0..15:
      boneSheet.col(col).width = 12
  
  workbook.save("animation_dump.xlsx")
  echo &"Animation data dumped to animation_dump.xlsx ({animComp.animations.len} animations, first 3 processed)"
