//
//  MOPUBNativeVideoAdAdapter+Testing.h
//  MoPubSDKTests
//
//  Copyright © 2017 MoPub. All rights reserved.
//

#import "MOPUBNativeVideoAdAdapter.h"
#import "MPAdImpressionTimer.h"
#import "MPAdDestinationDisplayAgent.h"

@interface MOPUBNativeVideoAdAdapter (Testing)

@property (nonatomic) MPAdImpressionTimer *impressionTimer;
@property (nonatomic, strong) MPAdDestinationDisplayAgent *destinationDisplayAgent;

@end

// Defining a separate interface suppresses the warning that this
// method doesn't exist in the implementation.
@interface MOPUBNativeVideoAdAdapter (ExposeMethodsForTesting)

- (void)willAttachToView:(UIView *)view;

@end
