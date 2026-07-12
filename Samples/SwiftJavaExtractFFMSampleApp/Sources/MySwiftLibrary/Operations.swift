public struct MyVector2 {
  public var x: Int
  public var y: Int

  public init(x: Int, y: Int) {
    self.x = x
    self.y = y
  }

  public func getX() -> Int {
    self.x
  }

  public func getY() -> Int {
    self.y
  }

  public static func + (lhs: MyVector2, rhs: MyVector2) -> MyVector2 {
    MyVector2(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
  }
}
