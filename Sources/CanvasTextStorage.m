//
//  CanvasTextStorage.m
//  CanvasText
//
//  Created by Sam Soffes on 6/17/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

#import "CanvasTextStorage.h"

@interface CanvasTextStorage ()
@property (nonatomic) NSUInteger editCount;
@property (nonatomic) BOOL isReplacing;
@end

@implementation CanvasTextStorage

// MARK: - Properties

@synthesize editCount = _editCount;
@synthesize canvasDelegate = _canvasDelegate;
@synthesize isReplacing = _isReplacing;

- (BOOL)isEditing {
	return self.editCount > 0;
}


// MARK: - NSTextStorage

- (void)beginEditing {
	[super beginEditing];
	self.editCount += 1;
}

- (void)endEditing {
	[super endEditing];
	self.editCount -= 1;
}

/* It appears that the normal sequence in the call chain calls replaceString then setAttributes.  But when we are handling attributes, we need to get block that call, since sometimes it has the wrong range (when a markdown command shrinks the total text, for instance.  So we override this function and the next.  This one puts up a barrier and the other honors the barrier to avoid the errored setAttributes call */
- (void) replaceCharactersInRange:(NSRange)range withAttributedString:(NSAttributedString *)attrString {
    self.isReplacing = true;
    [super replaceCharactersInRange:range withAttributedString: attrString];
    self.isReplacing = false;
    // Block call for set attributed after this
}

- (void)setAttributes:(NSDictionary<NSString *,id> *)attributes range:(NSRange)range {
    if (self.isReplacing) {
        return;
    } // See linkage to code above
    
    if (NSMaxRange(range) > self.length) {
        NSLog(@"WARNING: Tried to set attributes at out of bounds range %@. Length: %lu", NSStringFromRange(range), (unsigned long)self.length);
        return;
    }
    [super setAttributes: attributes range: range];
}


- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)aString {
	// Local changes are delegated to the text controller
	[self.canvasDelegate canvasTextStorage:self willReplaceCharactersInRange:range withString:aString];
}


- (void)actuallyReplaceCharactersInRange:(NSRange)range withString:(NSString *)aString {
	[super replaceCharactersInRange:range withString:aString];
}

@end
