struct AnalysisResult {
  let importedTypes: [String: ImportedNominalType]
  let importedGlobalVariables: [ImportedFunc]
  let importedGlobalFuncs: [ImportedFunc]
}
