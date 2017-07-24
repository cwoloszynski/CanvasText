//
//  ViewController.swift
//  Example
//
//  Created by Sam Soffes on 2/17/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

import UIKit
import WebKit
import CanvasText

class ViewController: UIViewController {

	// MARK: - Properties

	let textController = TextController(serverURL: URL(string: "https://localhost")!, accessToken: "XYZ", organizationID: "ACME", canvasID: "123", theme: ExampleTheme())
	let textView: UITextView

	fileprivate var ignoreSelectionChange = false


	// MARK: - Initializers

	override init(nibName: String?, bundle: Bundle?) {
		let textView = TextView(frame: .zero, textContainer: textController.textContainer)
		textView.translatesAutoresizingMaskIntoConstraints = false
		textView.alwaysBounceVertical = true
		self.textView = textView
		
		super.init(nibName: nil, bundle: nil)

		textController.connectionDelegate = self
		// FIXME: textController.selectionDelegate = self
		textController.annotationDelegate = textView
		textView.delegate = self
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}


	// MARK: - UIViewController

	override func loadView() {
		view = textView
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		title = "Example"

		/* FIXME: This is no longer needed in this section of code
		
		guard let accessToken = UserDefaults.standard.string(forKey: "AccessToken") else {
			fatalError("Access token is not set. Please set your access token in AppDelegate.swift and rerun the app.")
		} */

		// Blank "7bBmNtv3qVKK4plJBRAS0L"
		// Demo  "3Fn14Jt9e9hF59sy4FhTAl"
		// Long  "5kbzOyFgWIRjJBAnIrFLQ4"

		textController.connect()
			/* 
			// FIXME: Looks like this information is needed at construction, not
			// at connect()
			serverURL: URL(string: "wss://canvas-realtime-staging.herokuapp.com")!,
			accessToken: accessToken,
			organizationID: "eaedcdb7-a0d5-4415-95a7-50b78316c910",
			canvasID: "7bBmNtv3qVKK4plJBRAS0L"
		) */
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		textView.becomeFirstResponder()
	}

	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
		// FIXME: textController.horizontalSizeClass = traitCollection.horizontalSizeClass
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

		let maxWidth: CGFloat = 640
		let padding = max(16 - textView.textContainer.lineFragmentPadding, (textView.bounds.width - maxWidth) / 2)
		textView.textContainerInset = UIEdgeInsets(top: 16, left: padding, bottom: 32, right: padding)
		textController.textContainerInset = textView.textContainerInset
	}
}


extension ViewController: UITextViewDelegate {
	func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
		ignoreSelectionChange = true
		return true
	}

	func textViewDidChangeSelection(_ textView: UITextView) {
		textController.presentationSelectedRange = textView.isFirstResponder ? textView.selectedRange : nil
	}

	func textViewDidEndEditing(_ textView: UITextView) {
		textController.presentationSelectedRange = nil
	}
}


/* extension ViewController: TextControllerSelectionDelegate {
	func textControllerDidUpdateSelectedRange(_ textController: TextController) {
		if ignoreSelectionChange {
			ignoreSelectionChange = false
			return
		}

		guard let selectedRange = textController.presentationSelectedRange else {
			textView.selectedRange = NSRange(location: 0, length: 0)
			return
		}

		if !NSEqualRanges(textView.selectedRange, selectedRange) {
			textView.selectedRange = selectedRange
		}
	}
} */


extension ViewController: TextControllerConnectionDelegate {
	func textControllerDidConnect(_ textController: TextController) {
		// FIXME:
	}
	
	func textController(_ textController: TextController, didDisconnectWithErrorMessage errorMessage: String?) {
		// FIXME:
	}

	func textController(_ textController: TextController, didReceiveWebErrorMessage errorMessage: String?, lineNumber: UInt?, columnNumber: UInt?) {
		// FIXME:
	}
	
	func textController(_ textController: TextController, willConnectWithWebView webView: WKWebView) {
		webView.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
		view.addSubview(webView)
	}
}
