//
//  Theme+Default.swift
//  CanvasText
//
//  Created by Sam Soffes on 6/7/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

#if os(OSX)
	import AppKit
#else
	import UIKit
#endif

import CanvasNative
import X

extension Theme {
	public var fontSize: CGFloat {
		return UIFont.preferredFont(forTextStyle: UIFontTextStyle.body).pointSize
	}

	fileprivate var listIndentation: CGFloat {
		let font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
        return ("      " as NSString).size(withAttributes: [NSAttributedStringKey.font: font]).width
	}

	public var baseAttributes: Attributes {
		return [
            NSAttributedStringKey.foregroundColor: foregroundColor,
            NSAttributedStringKey.font: TextStyle.body.font()
		]
	}

	public var titleAttributes: Attributes {
		var attributes = baseAttributes
        attributes[NSAttributedStringKey.foregroundColor] = foregroundColor
        attributes[NSAttributedStringKey.font] = TextStyle.title1.font(weight: .semibold)
		return attributes
	}

	public func foldingAttributes(parentAttributes: Attributes) -> Attributes {
		var attributes = parentAttributes
        attributes[NSAttributedStringKey.foregroundColor] = foldedColor
		return attributes
	}

	public func blockSpacing(block: BlockNode, horizontalSizeClass: UserInterfaceSizeClass) -> BlockSpacing {
		var spacing = BlockSpacing(marginBottom: round(fontSize * 1.5))

		// No margin if it's not at the bottom of a positionable list
		if let block = block as? Positionable, !(block is Blockquote) {
			if !block.position.isBottom {
				spacing.marginBottom = 4
			}
		}

		// Heading spacing
		if block is Heading {
			spacing.marginTop = round(spacing.marginBottom * 0.25)
			spacing.marginBottom = round(spacing.marginBottom / 2)
			return spacing
		}

		// Indentation
		if let listable = block as? Listable {
			spacing.paddingLeft = round(listIndentation * CGFloat(listable.indentation.rawValue + 1))
			return spacing
		}

		if let code = block as? CodeBlock {
			let padding: CGFloat = 8
			let margin: CGFloat = 5

			// Top margin
			if code.position.isTop {
				spacing.paddingTop += padding
				spacing.marginTop += margin
			}

			// Bottom margin
			if code.position.isBottom {
				spacing.paddingBottom += padding
				spacing.marginBottom += margin
			}

			spacing.paddingLeft = padding * 2

			// Indent for line numbers
			if horizontalSizeClass == .regular {
				// TODO: Don't hard code
				spacing.paddingLeft += 40
			}

			return spacing
		}

		if let blockquote = block as? Blockquote {
			let padding: CGFloat = 4

			// Top margin
			if blockquote.position.isTop {
				spacing.paddingTop += padding
			}

			// Bottom margin
			if blockquote.position.isBottom {
				spacing.paddingBottom += padding
			}

			spacing.paddingLeft = listIndentation

			return spacing
		}

		return spacing
	}

	public func attributes(block: BlockNode) -> Attributes {
		if block is Title {
			return titleAttributes
		}

		var attributes = baseAttributes

		if let heading = block as? Heading {
			switch heading.level {
			case .one:
                attributes[NSAttributedStringKey.foregroundColor] = headingOneColor
                attributes[NSAttributedStringKey.font] = TextStyle.title1.font(weight: .medium)
			case .two:
                attributes[NSAttributedStringKey.foregroundColor] = headingTwoColor
                attributes[NSAttributedStringKey.font] = TextStyle.title2.font(weight: .medium)
			case .three:
                attributes[NSAttributedStringKey.foregroundColor] = headingThreeColor
                attributes[NSAttributedStringKey.font] = TextStyle.title3.font(weight: .medium)
			case .four:
                attributes[NSAttributedStringKey.foregroundColor] = headingFourColor
                attributes[NSAttributedStringKey.font] = TextStyle.headline.font(weight: .medium)
			case .five:
                attributes[NSAttributedStringKey.foregroundColor] = headingFiveColor
                attributes[NSAttributedStringKey.font] = TextStyle.headline.font(weight: .medium)
			case .six:
                attributes[NSAttributedStringKey.foregroundColor] = headingSixColor
                attributes[NSAttributedStringKey.font] = TextStyle.headline.font(weight: .medium)
			}
		}

		else if block is CodeBlock {
            attributes[NSAttributedStringKey.foregroundColor] = codeColor
            attributes[NSAttributedStringKey.font] = TextStyle.body.monoSpaceFont()

			// Indent wrapped lines in code blocks
			let paragraph = NSMutableParagraphStyle()
			paragraph.headIndent = floor(fontSize * 1.2) + 0.5
            attributes[NSAttributedStringKey.paragraphStyle] = paragraph
		}

		else if block is Blockquote {
            attributes[NSAttributedStringKey.foregroundColor] = blockquoteColor
		}

		return attributes
	}

	public func attributes(span: SpanNode, parentAttributes: Attributes) -> Attributes? {
        guard let currentFont = parentAttributes[NSAttributedStringKey.font] as? X.Font else { return nil }
		var traits = currentFont.symbolicTraits
		var attributes = parentAttributes

		if span is CodeSpan {
			let monoSpaceFont = UIFont(name: "Menlo", size: currentFont.pointSize * 0.9)!
			let font = applySymbolicTraits(traits, toFont: monoSpaceFont)
            attributes[NSAttributedStringKey.font] = font
            attributes[NSAttributedStringKey.foregroundColor] = codeSpanColor
            attributes[NSAttributedStringKey.backgroundColor] = codeSpanBackgroundColor
		}

		else if span is Strikethrough {
            attributes[NSAttributedStringKey.strikethroughStyle] = NSUnderlineStyle.styleThick
            attributes[NSAttributedStringKey.strikethroughColor] = strikethroughColor
            attributes[NSAttributedStringKey.foregroundColor] = strikethroughColor
		}

		else if span is DoubleEmphasis {
			traits.insert(.traitBold)
            attributes[NSAttributedStringKey.font] = applySymbolicTraits(traits, toFont: currentFont)
		}

		else if span is Emphasis {
			traits.insert(.traitItalic)
            attributes[NSAttributedStringKey.font] = applySymbolicTraits(traits, toFont: currentFont)
		}

		else if span is Link {
            attributes[NSAttributedStringKey.foregroundColor] = tintColor
		}

		// If there aren't any attributes set yet, return nil and inherit from parent.
		if attributes.isEmpty {
			return nil
		}
		
		return attributes
	}
}
