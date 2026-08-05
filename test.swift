let p = "C:/swift-java/Samples/Optionals.swift"
let name = p.split { $0 == "/" || $0 == "\\" }.last ?? "Unknown"
print("\(name)")
