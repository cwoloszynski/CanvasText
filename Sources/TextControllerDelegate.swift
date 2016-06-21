//
//  TextControllerDelegate.swift
//  CanvasText
//
//  Created by Sam Soffes on 6/21/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

import CanvasNative
import WebKit

public protocol TextControllerConnectionDelegate: class {
	func textController(textController: TextController, willConnectWithWebView webView: WKWebView)
	func textControllerDidConnect(textController: TextController)
	func textController(textController: TextController, didReceiveWebErrorMessage errorMessage: String?, lineNumber: UInt?, columnNumber: UInt?)
	func textController(textController: TextController, didDisconnectWithErrorMessage errorMessage: String?)
}


public protocol TextControllerDisplayDelegate: class {
	func textController(textController: TextController, didUpdateSelectedRange selectedRange: NSRange)
	func textController(textController: TextController, didUpdateTitle title: String?)
	func textControllerWillProcessRemoteEdit(textController: TextController)
	func textControllerDidProcessRemoteEdit(textController: TextController)
	func textController(textController: TextController, URLForImage block: CanvasNative.Image) -> NSURL?
	func textControllerDidUpdateFolding(textController: TextController)
}


public protocol TextControllerAnnotationDelegate: class {
	func textController(textController: TextController, willAddAnnotation annotation: Annotation)
	func textController(textController: TextController, willRemoveAnnotation annotation: Annotation)
}
