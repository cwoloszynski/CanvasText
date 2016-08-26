//
//  TextStyle.swift
//  CanvasText
//
//  Created by Sam Soffes on 6/30/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

import X

public extension TextStyle {
	public func font(traits traits: FontDescriptorSymbolicTraits = [], minimumWeight: FontWeight? = nil) -> Font {
		var systemFont = Font.preferredFontForTextStyle(self)

		// Apply minimum weight
		if let minimumWeight = minimumWeight {
			#if os(OSX)
				let currentWeight = (systemFont.fontDescriptor.objectForKey(NSFontFaceAttribute) as? String).flatMap(FontWeight.init)
				if minimumWeight.weight > currentWeight?.weight ?? 0 {
					systemFont = Font.systemFontOfSize(systemFont.pointSize, weight: minimumWeight)
				}
			#else
				let currentWeight = (systemFont.fontDescriptor().objectForKey(UIFontDescriptorFaceAttribute) as? String).flatMap(FontWeight.init)
				if minimumWeight.weight > currentWeight?.weight ?? 0 {
					systemFont = Font.systemFontOfSize(systemFont.pointSize, weight: minimumWeight)
				}
			#endif
		}

		return applySymbolicTraits(traits, toFont: systemFont, sanitize: false)
	}
	
	public func monoSpaceFont(traits traits: FontDescriptorSymbolicTraits = []) -> Font {
		let systemFont = Font.preferredFontForTextStyle(self)
		let monoSpaceFont = Font(name: "Menlo", size: systemFont.pointSize * 0.9)!
		return applySymbolicTraits(traits, toFont: monoSpaceFont)
	}
}


func applySymbolicTraits(traits: FontDescriptorSymbolicTraits, toFont font: Font, sanitize: Bool = true) -> Font {
	var traits = traits

	if sanitize && !traits.isEmpty {
		var t = FontDescriptorSymbolicTraits()

		if traits.contains(.TraitBold) {
			t.insert(.TraitBold)
		}

		if traits.contains(.TraitItalic) {
			t.insert(.TraitItalic)
		}

		traits = t
	}

	if traits.isEmpty {
		return font
	}

	#if os(OSX)
		let fontDescriptor = font.fontDescriptor.fontDescriptorWithSymbolicTraits(traits.symbolicTraits)
		return Font(descriptor: fontDescriptor, size: font.pointSize) ?? font
	#else
		let fontDescriptor = font.fontDescriptor().fontDescriptorWithSymbolicTraits(traits)
		return Font(descriptor: fontDescriptor, size: font.pointSize)
	#endif
}
