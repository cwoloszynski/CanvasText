//
//  TextControllerTests.swift
//  CanvasTextTests-iOS
//
//  Created by Charlie Woloszynski on 12/28/17.
//  Copyright © 2017 Canvas Labs, Inc. All rights reserved.
//

import XCTest
@testable import CanvasText

import X
public struct Swatch {
    
    // MARK: - Base
    
    public static let black = Color(red: 0.161, green: 0.180, blue: 0.192, alpha: 1)
    public static let white = Color.white
    public static let darkGray = Color(red: 0.35, green:0.35, blue: 0.35, alpha: 1)
    public static let warmGray = Color(red: 0.5, green: 0.25, blue: 0.25, alpha: 1)
    public static let gray = Color(red: 0.752, green: 0.796, blue: 0.821, alpha: 1)
    public static let lightGray = Color(red: 0.906, green: 0.918, blue: 0.925, alpha: 1)
    public static let extraLightGray = Color(red: 0.961, green: 0.969, blue: 0.976, alpha: 1)
    
    public static let blue = Color(red: 0.255, green:0.306, blue: 0.976, alpha: 1)
    public static let lightBlue = Color(red: 0.188, green: 0.643, blue: 1, alpha: 1)
    public static let green = Color(red: 0.157, green:0.859, blue: 0.404, alpha: 1)
    public static let pink = Color(red: 1, green: 0.216, blue: 0.502, alpha: 1)
    public static let yellow = Color(red: 1, green: 0.942, blue: 0.716, alpha: 1)
    public static let red = Color(red:0.976, green: 0.306, blue: 0.255, alpha: 1)
    
    public static let ultraviolet = Color(hex: "#5F4B8B")! // Ultra Violet
    
    // MARK: - Shared
    
    public static let brand = ultraviolet
    public static let destructive = red
    public static let comment = yellow
    
    
    // MARK: - Bars
    
    public static let border = gray
    
    
    // MARK: - Tables
    
    public static let groupedTableBackground = extraLightGray
    
    /// Chevron in table view cells
    public static let cellDisclosureIndicator = darkGray
}

public struct LightTheme: Theme {
    
    // MARK: - Primary Colors
    
    public let backgroundColor = Swatch.white
    public let foregroundColor = Swatch.black
    public var tintColor: Color
    
    
    // MARK: - Block Colors
    
    public let titlePlaceholderColor = Swatch.lightGray
    public let bulletColor = Swatch.darkGray
    public let uncheckedCheckboxColor = Swatch.darkGray
    public let orderedListItemNumberColor = Swatch.darkGray
    public let codeColor = Swatch.darkGray
    public let codeBlockBackgroundColor = Swatch.extraLightGray
    public let codeBlockLineNumberColor = Swatch.gray
    public let codeBlockLineNumberBackgroundColor = Swatch.lightGray
    public let blockquoteColor = Swatch.darkGray
    public let blockquoteBorderColor = Swatch.lightGray
    public let headingOneColor = Swatch.warmGray
    public let headingTwoColor = Swatch.warmGray
    public let headingThreeColor = Swatch.warmGray
    public let headingFourColor = Swatch.warmGray
    public let headingFiveColor = Swatch.warmGray
    public let headingSixColor = Swatch.warmGray
    public let horizontalRuleColor = Swatch.darkGray
    public let imagePlaceholderColor = Swatch.darkGray
    public let imagePlaceholderBackgroundColor = Swatch.extraLightGray
    
    
    // MARK: - Span Colors
    
    public let foldedColor = Swatch.darkGray
    public let strikethroughColor = Swatch.darkGray
    public let linkURLColor = Swatch.darkGray
    public let codeSpanColor = Swatch.darkGray
    public let codeSpanBackgroundColor = Swatch.extraLightGray
    public let commentBackgroundColor = Swatch.comment
    
    
    // MARK: - Initializers
    
    public init(tintColor: Color) {
        self.tintColor = tintColor
    }
}

class TextControllerTests: XCTestCase {
    
    fileprivate var textController: TextController?
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        let projectID = UUID().uuidString.lowercased()
        let canvasID = UUID().uuidString.lowercased()
        textController = TextController(
            projectUUID: projectID,
            canvasUUID: canvasID,
            theme: LightTheme(tintColor: Swatch.brand)
        )
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
