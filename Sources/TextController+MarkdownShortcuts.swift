//
//  TextController+MarkdownShortcuts.swift
//  CanvasText
//
//  Created by Sam Soffes on 4/15/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

import Foundation
import CanvasNative

private typealias Match = (replacement: String, range: NSRange)

extension TextController {
    //
    // This function (once called processMarkdownShortcuts) is really about transforming the edited text in both
    // directions (from Markdown to Native as well as from Native back to Markdown)
    //
	func processTransformations(_ presentationRange: NSRange) {
		let text = currentDocument.presentationString as NSString

		var searchRange = presentationRange
		if searchRange.max >= text.length {
			searchRange.length = text.length - searchRange.location
		}
		searchRange = text.lineRange(for: searchRange)

		// TODO: This fails if there is more than one line of markdown pasted since it's relative to the node before
		// we make any changes.
        // FIXME: See note above, this needs to be fixed!
		text.enumerateSubstrings(in: searchRange, options: .byLines) { [weak self] string, range, _, _ in
			guard let string = string,
				let document = self?.currentDocument,
				let node = document.blockAt(presentationLocation: range.location), (string as NSString).length > 0
			else { return }

			// FIXME: Update to support inline markers
			let backingRange = document.backingRanges(presentationRange: range)[0]
			var replacementRange = backingRange
			let replacement: String

			if let node = node as? UnorderedListItem, let match = self?.prefixForUnorderedList(string, unorderedListItem: node) {
				replacement = match.replacement
				replacementRange = node.nativePrefixRange
				replacementRange.length += match.range.location
			} else if node is Paragraph, let match = self?.prefixForParagraph(string) {
				replacement = match.replacement
				replacementRange.length = match.range.location
            } else {
                return
            }

			// Replace
			self?.edit(backingRange: replacementRange, replacement: replacement)

			// Reset selection
			guard var selection = self?.presentationSelectedRange else { return }
			selection.length = 0

			DispatchQueue.main.async() {
				self?.setPresentationSelectedRange(selection, updateTextView: true)
			}
		}
	}


	// MARK: - Private

	fileprivate func prefixForUnorderedList(_ string: String, unorderedListItem: UnorderedListItem? = nil) -> Match? {
		let scanner = Scanner(string: string)
		scanner.charactersToBeSkipped = nil

		// Checklist item
		if let native = scanChecklist(scanner, unorderedListItem: unorderedListItem) {
            return (native, NSRange(location: scanner.scanLocation, length: 0)) // FIXME: Length is not accurate but is not used by caller
		}

		return nil
	}

	fileprivate func prefixForParagraph(_ string: String) -> Match? {
		let scanner = Scanner(string: string)
		scanner.charactersToBeSkipped = nil

		// Blockquote
		if let native = scanBlockquote(scanner) {
            return (native, NSRange(location: scanner.scanLocation, length: 0)) // FIXME: Length is not accurate but is not used by caller
		}

		// Checklist item
		scanner.scanLocation = 0
		if let native = scanChecklist(scanner) {
			return (native, NSRange(location: scanner.scanLocation, length: 0)) // FIXME: Length is not accurate but is not used by caller
		}

		// Unordered list
		scanner.scanLocation = 0
		if let native = scanUnorderedList(scanner) {
			return (native, NSRange(location: scanner.scanLocation, length: 0)) // FIXME: Length is not accurate but is not used by caller
		}

		// Ordered list
		scanner.scanLocation = 0
		if let native = scanOrderedList(scanner) {
			return (native, NSRange(location: scanner.scanLocation, length: 0)) // FIXME: Length is not accurate but is not used by caller
		}
        
        // Merged horizontal rules
        scanner.scanLocation = 0
        if let native = scanMergedHorizontalRules(scanner) {
            // After the scan, the location moves to the next position after the matched text.
            // The location becomes the length of the match.
            // FIXME:  The return value should use the length field to convey the length of the match and the
            // location to convey the start of the match.
            // FIXME:
            // FIXME:  This is ugly with this misuse of the two values in the return and their intrepretation above.
            //
            let location = scanner.scanLocation
            return (native, NSRange(location: location, length: 0)) // FIXME: Length is not accurate but is not used by caller
        }
        
        // Preceeding horizontal rules
        scanner.scanLocation = 0
        if let native = scanUnterminatedHorizontalRule(scanner) {
            let location = scanner.scanLocation
            return (native, NSRange(location: location, length: 0)) // FIXME: Length is not accurate but is not used by caller
        }

		return nil
	}

	fileprivate func scanBlockquote(_ scanner: Scanner) -> String? {
		guard scanner.scanString("> ", into: nil) else { return nil }
		return Blockquote.nativeRepresentation()
	}
    
    fileprivate func scanMergedHorizontalRules(_ scanner: Scanner) -> String? {
        guard scanner.scanString(HorizontalRule.nativeRepresentation()+HorizontalRule.nativeRepresentation(), into: nil) else { return nil }
        return "------"
    }

    fileprivate func scanUnterminatedHorizontalRule(_ scanner: Scanner) -> String? {
        guard scanner.scanString(HorizontalRule.nativeRepresentation(), into: nil) else { return nil }
        return "---"
    }

	fileprivate func scanChecklist(_ scanner: Scanner, unorderedListItem: UnorderedListItem? = nil) -> String? {
		let indentation: Indentation

		if let unorderedListItem = unorderedListItem {
			indentation = unorderedListItem.indentation
		} else {
			indentation = scanIndentation(scanner)

			guard scanner.scanString("-", into: nil) || scanner.scanString("*", into: nil) else { return nil }

			// Optional space
			scanner.scanString(" ", into: nil)
		}

		// Leading delimiter
		guard scanner.scanString("[", into: nil) else { return nil }

		// State
		let state: ChecklistItem.State
		if !scanner.scanString(" ", into: nil) {
			if scanner.scanString("x", into: nil) {
				state = .checked
			} else {
				state = .unchecked
			}
		} else {
			state = .unchecked
		}

		// Trailing delimiter with required trailing space
		guard scanner.scanString("] ", into: nil) else { return nil }

		return ChecklistItem.nativeRepresentation(indentation: indentation, state: state)
	}

	fileprivate func scanUnorderedList(_ scanner: Scanner) -> String? {
		let indentation = scanIndentation(scanner)
		let set = CharacterSet(charactersIn: "-*")
		guard scanner.scanCharacters(from: set, into: nil) && scanner.scanString(" ", into: nil) else {
			return nil
		}

		return UnorderedListItem.nativeRepresentation(indentation: indentation)
	}

	fileprivate func scanOrderedList(_ scanner: Scanner) -> String? {
		let indentation = scanIndentation(scanner)
		guard scanner.scanInt32(nil) && scanner.scanString(". ", into: nil) else { return nil }

		return OrderedListItem.nativeRepresentation(indentation: indentation)
	}

	fileprivate func scanIndentation(_ scanner: Scanner) -> Indentation {
		var level: UInt = 0
		while scanner.scanString("    ", into: nil) || scanner.scanString("\t", into: nil) {
			level += 1
		}
		return Indentation(rawValue: level) ?? .three
	}
}
