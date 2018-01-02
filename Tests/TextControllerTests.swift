//
//  TextControllerTests.swift
//  CanvasTextTests-iOS
//
//  Created by Charlie Woloszynski on 12/28/17.
//  Copyright © 2017 Canvas Labs, Inc. All rights reserved.
//

import XCTest
import CanvasNative
import X

@testable import CanvasText


// From: https://www.raizlabs.com/dev/2017/02/xctest-optional-unwrapping/
struct UnexpectedNilError: Error {}
func AssertNotNilAndUnwrap<T>(_ variable: T?, message: String = "Unexpected nil variable", file: StaticString = #file, line: UInt = #line) throws -> T {
    guard let variable = variable else {
        XCTFail(message, file: file, line: line)
        throw UnexpectedNilError()
    }
    return variable
}

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
    
    func testConstructor() throws {
        
        // This will create a document controller (and a persistence controller) and try to load the
        // document.  Since the uuids are invalid, it will create a blank document.
        let textController = try AssertNotNilAndUnwrap(self.textController)
        textController.loadDocument()
        
        let startingPresentationString = textController.currentDocument.presentationString
        
        XCTAssertEqual(startingPresentationString, "Untitled")
        let startingBackingString = textController.currentDocument.backingString
        
        XCTAssert(startingBackingString.contains(textController.canvasUUID))
        XCTAssert(startingBackingString.hasSuffix("Untitled"))
    }
    
    func testMarkdownBulletItemTransformation() throws {
        
        // This will create a document controller (and a persistence controller) and try to load the
        // document.  Since the uuids are invalid, it will create a blank document.
        let textController = try AssertNotNilAndUnwrap(self.textController)
        textController.loadDocument()
        
        let startingPresentationString = textController.currentDocument.presentationString
        XCTAssertEqual(startingPresentationString, "Untitled")
        
        let startingBackingString = textController.currentDocument.backingString
        XCTAssert(startingBackingString.contains(textController.canvasUUID))
        XCTAssert(startingBackingString.hasSuffix("Untitled"))
        
        let startingBlockCount = textController.currentDocument.blocks.count
        XCTAssertEqual(startingBlockCount, 1) // DocTitle
        
        let startingAnnotationCount = textController.annotationsController.annotations.count
        XCTAssertEqual(startingAnnotationCount, 1) // Not sure what the first annotation is, but it is in every document.
        XCTAssertEqual(annotationCount(for: textController.annotationsController.annotations, ofType: BulletView.self), 0)
        
        let canvasTextStorage = try AssertNotNilAndUnwrap(textController.textStorage as? CanvasTextStorage)
        
        // Append a bullet list to the end of the canvas
        var appendRange = NSRange(location: textController.currentDocument.presentationString.count, length: 0)
        textController.canvasTextStorage(canvasTextStorage, willReplaceCharactersIn: appendRange, with: "\n- One")
    
        // Confirm the '- ' is removed (the bullet is now in the annotations of the document)
        XCTAssertEqual(textController.currentDocument.presentationString, "Untitled\nOne")
        XCTAssertEqual(textController.currentDocument.blocks.count, 2)
        XCTAssertEqual(textController.annotationsController.annotations.count, startingAnnotationCount+1)
        XCTAssertEqual(annotationCount(for: textController.annotationsController.annotations, ofType: BulletView.self), 1)
        
        // And add a new line and confirm that we have TWO bullets (annotations)
        appendRange = NSRange(location: textController.currentDocument.presentationString.count, length: 0)
        textController.canvasTextStorage(canvasTextStorage, willReplaceCharactersIn: appendRange, with: "\n")
        XCTAssertEqual(textController.currentDocument.blocks.count, 3)
        XCTAssertEqual(textController.annotationsController.annotations.count, startingAnnotationCount+2)
        XCTAssertEqual(annotationCount(for: textController.annotationsController.annotations, ofType: BulletView.self), 2)
        XCTAssertEqual(textController.currentDocument.presentationString, "Untitled\nOne\n")
        
        // Add text to the new bullet list to flesh it out
        appendRange = NSRange(location: textController.currentDocument.presentationString.count, length: 0)
        textController.canvasTextStorage(canvasTextStorage, willReplaceCharactersIn: appendRange, with: "Two")
        XCTAssertEqual(textController.currentDocument.blocks.count, 3)
        XCTAssertEqual(textController.annotationsController.annotations.count, startingAnnotationCount+2)
        XCTAssertEqual(annotationCount(for: textController.annotationsController.annotations, ofType: BulletView.self), 2)
        XCTAssertEqual(textController.currentDocument.presentationString, "Untitled\nOne\nTwo")
        
        // And add newline to start a third bullet
        appendRange = NSRange(location: textController.currentDocument.presentationString.count, length: 0)
        textController.canvasTextStorage(canvasTextStorage, willReplaceCharactersIn: appendRange, with: "\n")
        XCTAssertEqual(textController.currentDocument.blocks.count, 4)
        XCTAssertEqual(textController.annotationsController.annotations.count, startingAnnotationCount+3)
        XCTAssertEqual(annotationCount(for: textController.annotationsController.annotations, ofType: BulletView.self), 3)
        XCTAssertEqual(textController.currentDocument.presentationString, "Untitled\nOne\nTwo\n")
        
        // And add another return (which cancels the bullet list and should clear the bullet annotation for that bullet list item)
        // But, be reminded that the annotation list may hold nils, etc, so we have to check if the list has BulletView annotations
        appendRange = NSRange(location: textController.currentDocument.presentationString.count, length: 0)
        textController.canvasTextStorage(canvasTextStorage, willReplaceCharactersIn: appendRange, with: "\n")
        XCTAssertEqual(textController.currentDocument.blocks.count, 4)
        XCTAssertEqual(textController.annotationsController.annotations.count, startingAnnotationCount+3)
        XCTAssertEqual(annotationCount(for: textController.annotationsController.annotations, ofType: BulletView.self), 2)
        XCTAssertEqual(textController.currentDocument.presentationString, "Untitled\nOne\nTwo\n")
    }
    
    func testMarkdownHorizontalRuleTransformation() throws {
        
        // This will create a document controller (and a persistence controller) and try to load the
        // document.  Since the uuids are invalid, it will create a blank document.
        let textController = try AssertNotNilAndUnwrap(self.textController)
        textController.loadDocument()
        
        let startingPresentationString = textController.currentDocument.presentationString
        XCTAssertEqual(startingPresentationString, "Untitled")
        
        let startingBackingString = textController.currentDocument.backingString
        XCTAssert(startingBackingString.contains(textController.canvasUUID))
        XCTAssert(startingBackingString.hasSuffix("Untitled"))
        
        let startingBlockCount = textController.currentDocument.blocks.count
        XCTAssertEqual(startingBlockCount, 1) // DocTitle
        
        let startingAnnotationCount = textController.annotationsController.annotations.count
        XCTAssertEqual(startingAnnotationCount, 1) // Not sure what the first annotation is, but it is in every document.
        XCTAssertEqual(annotationCount(for: textController.annotationsController.annotations, ofType: BulletView.self), 0)
        
        let canvasTextStorage = try AssertNotNilAndUnwrap(textController.textStorage as? CanvasTextStorage)
        
        // Append a bullet list to the end of the canvas
        var appendRange = NSRange(location: textController.currentDocument.presentationString.count, length: 0)
        textController.canvasTextStorage(canvasTextStorage, willReplaceCharactersIn: appendRange, with: "\n---")
        
        // Confirm the '---' is still there until a `newline` is processed
        XCTAssertEqual(textController.currentDocument.presentationString, "Untitled\n---")
        XCTAssertEqual(textController.currentDocument.blocks.count, 2)
        
        // Convert the '---' into a Horizontal Rule with a 'newline' and confirm the '---' is removed and a new Body is created

        appendRange = NSRange(location: textController.currentDocument.presentationString.count, length: 0)
        textController.canvasTextStorage(canvasTextStorage, willReplaceCharactersIn: appendRange, with: "\n")
        
        XCTAssertEqual(textController.currentDocument.presentationString, "Untitled\n\(HorizontalRule.attachmentCharacter)\n")
        XCTAssertEqual(textController.currentDocument.blocks.count, 3)
        
        // Delete the newline and confirm that the HR is still there
        appendRange = NSRange(location: textController.currentDocument.presentationString.count-1, length: 1)
        textController.canvasTextStorage(canvasTextStorage, willReplaceCharactersIn: appendRange, with: "")
        XCTAssertEqual(textController.currentDocument.presentationString, "Untitled\n\(HorizontalRule.attachmentCharacter)")
        XCTAssertEqual(textController.currentDocument.blocks.count, 2)
        
        // Delete the next character and confirm that the HR is now a Paragraph block
        appendRange = NSRange(location: textController.currentDocument.presentationString.count-1, length: 1)
        textController.canvasTextStorage(canvasTextStorage, willReplaceCharactersIn: appendRange, with: "")
        XCTAssertEqual(textController.currentDocument.presentationString, "Untitled\n")
        XCTAssertEqual(textController.currentDocument.blocks.count, 2)
        XCTAssert(type(of:textController.currentDocument.blocks[1]) == Paragraph.self)
        
        // Insert a HR (--- and then newline) and confirm it is created
        appendRange = NSRange(location: textController.currentDocument.presentationString.count, length: 0)
        textController.canvasTextStorage(canvasTextStorage, willReplaceCharactersIn: appendRange, with: "---")
        appendRange = NSRange(location: textController.currentDocument.presentationString.count, length: 0)
        textController.canvasTextStorage(canvasTextStorage, willReplaceCharactersIn: appendRange, with: "\n")
        XCTAssertEqual(textController.currentDocument.presentationString, "Untitled\n\(HorizontalRule.attachmentCharacter)\n")
        XCTAssertEqual(textController.currentDocument.blocks.count, 3)
        XCTAssert(type(of:textController.currentDocument.blocks[1]) == HorizontalRule.self)
        XCTAssert(type(of:textController.currentDocument.blocks[2]) == Paragraph.self)
        
        // Insert a 'A---' and see it is not transformed
        appendRange = NSRange(location: textController.currentDocument.presentationString.count, length: 0)
        textController.canvasTextStorage(canvasTextStorage, willReplaceCharactersIn: appendRange, with: "A---")
        appendRange = NSRange(location: textController.currentDocument.presentationString.count, length: 0)
        textController.canvasTextStorage(canvasTextStorage, willReplaceCharactersIn: appendRange, with: "\n")
        
        XCTAssertEqual(textController.currentDocument.presentationString, "Untitled\n\(HorizontalRule.attachmentCharacter)\nA---\n")
        XCTAssertEqual(textController.currentDocument.blocks.count, 4)
        XCTAssert(type(of:textController.currentDocument.blocks[1]) == HorizontalRule.self)
        XCTAssert(type(of:textController.currentDocument.blocks[2]) == Paragraph.self)
        XCTAssert(type(of:textController.currentDocument.blocks[3]) == Paragraph.self)
        
        // Now split that line at the 'A' and you should get the '---' transformed into an HR
        appendRange = NSRange(location: textController.currentDocument.presentationString.count-4, length: 0)
        textController.canvasTextStorage(canvasTextStorage, willReplaceCharactersIn: appendRange, with: "\n")
        XCTAssertEqual(textController.currentDocument.presentationString, "Untitled\n\(HorizontalRule.attachmentCharacter)\nA\n\(HorizontalRule.attachmentCharacter)\n")
        XCTAssertEqual(textController.currentDocument.blocks.count, 5)
        XCTAssert(type(of:textController.currentDocument.blocks[1]) == HorizontalRule.self)
        XCTAssert(type(of:textController.currentDocument.blocks[2]) == Paragraph.self)
        XCTAssert(type(of:textController.currentDocument.blocks[3]) == HorizontalRule.self)
        XCTAssert(type(of:textController.currentDocument.blocks[4]) == Paragraph.self)

    }
    
    // MARK: Support functions
    
    private func annotationCount(for annotations: [Annotation?], ofType targetType: ViewType.Type) -> Int {
        var count = 0
        for annotation in annotations {
            if let annotationView = annotation?.view, type(of: annotationView) == targetType { count += 1 }
        }
        return count
    }
    
    

}
