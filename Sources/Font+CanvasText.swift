//
//  TextStyle.swift
//  CanvasText
//
//  Created by Sam Soffes on 6/30/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

import X

public extension FontTextStyle {
	public func font(traits: FontDescriptorSymbolicTraits = [], minimumWeight: FontWeight? = nil) -> Font {
		var systemFont = Font.preferredFont(forTextStyle: self)

		// Apply minimum weight
		if let minimumWeight = minimumWeight {
			#if os(OSX)
				let currentWeight = (systemFont.fontDescriptor.object(forKey: NSFontFaceAttribute) as? String).flatMap(FontWeight.init)
				if minimumWeight.weight > currentWeight?.weight ?? 0 {
					systemFont = Font.systemFontOfSize(systemFont.pointSize, weight: minimumWeight)
				}
			#else
				let currentWeight = (systemFont.fontDescriptor.object(forKey: UIFontDescriptorFaceAttribute) as? String).flatMap(FontWeight.init)
				if minimumWeight.weight > currentWeight?.weight ?? 0 {
					systemFont = Font.systemFontOfSize(systemFont.pointSize, weight: minimumWeight)
				}
			#endif
		}

		return applySymbolicTraits(traits, toFont: systemFont, sanitize: false)
	}
	
	public func monoSpaceFont(traits: FontDescriptorSymbolicTraits = []) -> Font {
		let systemFont = Font.preferredFont(forTextStyle: self)
		let monoSpaceFont = Font(name: "Menlo", size: systemFont.pointSize * 0.9)!
		return applySymbolicTraits(traits, toFont: monoSpaceFont)
	}
}


func applySymbolicTraits(_ traits: FontDescriptorSymbolicTraits, toFont font: Font, sanitize: Bool = true) -> Font {
	var traits = traits

	if sanitize && !traits.isEmpty {
		var t = FontDescriptorSymbolicTraits()

		if traits.contains(.traitBold) {
			t.insert(.traitBold)
		}

		if traits.contains(.traitItalic) {
			t.insert(.traitItalic)
		}

		traits = t
	}

	if traits.isEmpty {
		return font
	}

	#if os(OSX)
		let fontDescriptor = font.fontDescriptor.withSymbolicTraits(traits.symbolicTraits)
		return Font(descriptor: fontDescriptor, size: font.pointSize) ?? font
	#else
		let fontDescriptor = font.fontDescriptor.withSymbolicTraits(traits)
		return Font(descriptor: fontDescriptor!, size: font.pointSize)
	#endif
}
