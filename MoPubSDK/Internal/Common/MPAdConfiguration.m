//
//  MPAdConfiguration.m
//  MoPub
//
//  Copyright (c) 2012 MoPub, Inc. All rights reserved.
//

#import "MPAdConfiguration.h"

#import "MOPUBExperimentProvider.h"
#import "MPAdServerKeys.h"
#import "MPConstants.h"
#import "MPLogging.h"
#import "MPRewardedVideoReward.h"
#import "MPViewabilityTracker.h"
#import "NSJSONSerialization+MPAdditions.h"
#import "NSString+MPAdditions.h"
#import "NSDictionary+MPAdditions.h"

#if MP_HAS_NATIVE_PACKAGE
#import "MPVASTTrackingEvent.h"
#endif

// MACROS
#define AFTER_LOAD_DURATION_MACRO   @"%%LOAD_DURATION_MS%%"
#define AFTER_LOAD_RESULT_MACRO   @"%%LOAD_RESULT%%"

NSString * const kAdTypeMetadataKey = @"x-adtype";
NSString * const kAdUnitWarmingUpMetadataKey = @"x-warmup";
NSString * const kClickthroughMetadataKey = @"x-clickthrough";
NSString * const kCreativeIdMetadataKey = @"x-creativeid";
NSString * const kCustomSelectorMetadataKey = @"x-customselector";
NSString * const kCustomEventClassNameMetadataKey = @"x-custom-event-class-name";
NSString * const kCustomEventClassDataMetadataKey = @"x-custom-event-class-data";
NSString * const kNextUrlMetadataKey = @"x-next-url";
NSString * const kBeforeLoadUrlMetadataKey = @"x-before-load-url";
NSString * const kAfterLoadUrlMetadataKey = @"x-after-load-url";
NSString * const kHeightMetadataKey = @"x-height";
NSString * const kImpressionTrackerMetadataKey = @"x-imptracker"; // Deprecated; "imptrackers" if available
NSString * const kImpressionTrackersMetadataKey = @"imptrackers";
NSString * const kLaunchpageMetadataKey = @"x-launchpage";
NSString * const kNativeSDKParametersMetadataKey = @"x-nativeparams";
NSString * const kNetworkTypeMetadataKey = @"x-networktype";
NSString * const kRefreshTimeMetadataKey = @"x-refreshtime";
NSString * const kAdTimeoutMetadataKey = @"x-ad-timeout-ms";
NSString * const kWidthMetadataKey = @"x-width";
NSString * const kDspCreativeIdKey = @"x-dspcreativeid";
NSString * const kPrecacheRequiredKey = @"x-precacheRequired";
NSString * const kIsVastVideoPlayerKey = @"x-vastvideoplayer";

NSString * const kInterstitialAdTypeMetadataKey = @"x-fulladtype";
NSString * const kOrientationTypeMetadataKey = @"x-orientation";

NSString * const kNativeImpressionMinVisiblePixelsMetadataKey = @"x-native-impression-min-px"; // The pixels Metadata takes priority over percentage, but percentage is left for backwards compatibility
NSString * const kNativeImpressionMinVisiblePercentMetadataKey = @"x-impression-min-visible-percent";
NSString * const kNativeImpressionVisibleMsMetadataKey = @"x-impression-visible-ms";
NSString * const kNativeVideoPlayVisiblePercentMetadataKey = @"x-play-visible-percent";
NSString * const kNativeVideoPauseVisiblePercentMetadataKey = @"x-pause-visible-percent";
NSString * const kNativeVideoMaxBufferingTimeMsMetadataKey = @"x-max-buffer-ms";
NSString * const kNativeVideoTrackersMetadataKey = @"x-video-trackers";

NSString * const kBannerImpressionVisableMsMetadataKey = @"x-banner-impression-min-ms";
NSString * const kBannerImpressionMinPixelMetadataKey = @"x-banner-impression-min-pixels";

NSString * const kAdTypeHtml = @"html";
NSString * const kAdTypeInterstitial = @"interstitial";
NSString * const kAdTypeMraid = @"mraid";
NSString * const kAdTypeClear = @"clear";
NSString * const kAdTypeNative = @"json";
NSString * const kAdTypeNativeVideo = @"json_video";

// rewarded video
NSString * const kRewardedVideoCurrencyNameMetadataKey = @"x-rewarded-video-currency-name";
NSString * const kRewardedVideoCurrencyAmountMetadataKey = @"x-rewarded-video-currency-amount";
NSString * const kRewardedVideoCompletionUrlMetadataKey = @"x-rewarded-video-completion-url";
NSString * const kRewardedCurrenciesMetadataKey = @"x-rewarded-currencies";

// rewarded playables
NSString * const kRewardedPlayableDurationMetadataKey = @"x-rewarded-duration";
NSString * const kRewardedPlayableRewardOnClickMetadataKey = @"x-should-reward-on-click";

// native video
NSString * const kNativeVideoTrackerUrlMacro = @"%%VIDEO_EVENT%%";
NSString * const kNativeVideoTrackerEventsMetadataKey = @"events";
NSString * const kNativeVideoTrackerUrlsMetadataKey = @"urls";
NSString * const kNativeVideoTrackerEventDictionaryKey = @"event";
NSString * const kNativeVideoTrackerTextDictionaryKey = @"text";

// clickthrough experiment
NSString * const kClickthroughExperimentBrowserAgent = @"x-browser-agent";
static const NSInteger kMaximumVariantForClickthroughExperiment = 2;

// viewability
NSString * const kViewabilityDisableMetadataKey = @"x-disable-viewability";

// advanced bidding
NSString * const kAdvancedBiddingMarkupMetadataKey = @"adm";

@interface MPAdConfiguration ()

@property (nonatomic, copy) NSString *adResponseHTMLString;
@property (nonatomic, strong, readwrite) NSArray *availableRewards;
@property (nonatomic) MOPUBDisplayAgentType clickthroughExperimentBrowserAgent;
@property (nonatomic, copy) NSString *afterLoadUrlWithMacros;

- (MPAdType)adTypeFromMetadata:(NSDictionary *)metadata;
- (NSString *)networkTypeFromMetadata:(NSDictionary *)metadata;
- (NSTimeInterval)refreshIntervalFromMetadata:(NSDictionary *)metadata;
- (NSDictionary *)dictionaryFromMetadata:(NSDictionary *)metadata forKey:(NSString *)key;
- (NSURL *)URLFromMetadata:(NSDictionary *)metadata forKey:(NSString *)key;
- (Class)setUpCustomEventClassFromMetadata:(NSDictionary *)metadata;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation MPAdConfiguration

- (id)initWithMetadata:(NSDictionary *)metadata data:(NSData *)data
{
    self = [super init];
    if (self) {
        self.adResponseData = data;

        self.adType = [self adTypeFromMetadata:metadata];
        self.adUnitWarmingUp = [metadata mp_boolForKey:kAdUnitWarmingUpMetadataKey];

        self.networkType = [self networkTypeFromMetadata:metadata];
        self.networkType = self.networkType ? self.networkType : @"";

        self.preferredSize = CGSizeMake([metadata mp_floatForKey:kWidthMetadataKey],
                                        [metadata mp_floatForKey:kHeightMetadataKey]);

        self.clickTrackingURL = [self URLFromMetadata:metadata
                                              forKey:kClickthroughMetadataKey];
        self.nextURL = [self URLFromMetadata:metadata
                                         forKey:kNextUrlMetadataKey];
        self.beforeLoadURL = [self URLFromMetadata:metadata forKey:kBeforeLoadUrlMetadataKey];
        self.afterLoadUrlWithMacros = [metadata objectForKey:kAfterLoadUrlMetadataKey];
        self.interceptURLPrefix = [self URLFromMetadata:metadata
                                                forKey:kLaunchpageMetadataKey];

        self.refreshInterval = [self refreshIntervalFromMetadata:metadata];
        self.adTimeoutInterval = [self timeIntervalFromMsmetadata:metadata forKey:kAdTimeoutMetadataKey];

        self.nativeSDKParameters = [self dictionaryFromMetadata:metadata
                                                        forKey:kNativeSDKParametersMetadataKey];
        self.customSelectorName = [metadata objectForKey:kCustomSelectorMetadataKey];

        self.orientationType = [self orientationTypeFromMetadata:metadata];

        self.customEventClass = [self setUpCustomEventClassFromMetadata:metadata];

        self.customEventClassData = [self customEventClassDataFromMetadata:metadata];

        self.dspCreativeId = [metadata objectForKey:kDspCreativeIdKey];

        self.precacheRequired = [metadata mp_boolForKey:kPrecacheRequiredKey];

        self.isVastVideoPlayer = [metadata mp_boolForKey:kIsVastVideoPlayerKey];

        self.creationTimestamp = [NSDate date];

        self.creativeId = [metadata objectForKey:kCreativeIdMetadataKey];

        self.metadataAdType = [metadata objectForKey:kAdTypeMetadataKey];

        self.nativeVideoPlayVisiblePercent = [self percentFromMetadata:metadata forKey:kNativeVideoPlayVisiblePercentMetadataKey];

        self.nativeVideoPauseVisiblePercent = [self percentFromMetadata:metadata forKey:kNativeVideoPauseVisiblePercentMetadataKey];

        self.nativeImpressionMinVisiblePixels = [[self adAmountFromMetadata:metadata key:kNativeImpressionMinVisiblePixelsMetadataKey] floatValue];

        self.nativeImpressionMinVisiblePercent = [self percentFromMetadata:metadata forKey:kNativeImpressionMinVisiblePercentMetadataKey];

        self.nativeImpressionMinVisibleTimeInterval = [self timeIntervalFromMsmetadata:metadata forKey:kNativeImpressionVisibleMsMetadataKey];

        self.nativeVideoMaxBufferingTime = [self timeIntervalFromMsmetadata:metadata forKey:kNativeVideoMaxBufferingTimeMsMetadataKey];
#if MP_HAS_NATIVE_PACKAGE
        self.nativeVideoTrackers = [self nativeVideoTrackersFromMetadata:metadata key:kNativeVideoTrackersMetadataKey];
#endif

        self.impressionMinVisibleTimeInSec = [self timeIntervalFromMsmetadata:metadata forKey:kBannerImpressionVisableMsMetadataKey];
        self.impressionMinVisiblePixels = [[self adAmountFromMetadata:metadata key:kBannerImpressionMinPixelMetadataKey] floatValue];

        // Organize impression tracking URLs
        // Get array of URL strings from the JSON
        NSArray <NSString *> * urlStrings = metadata[kImpressionTrackersMetadataKey];
        // Check to see if the array actually contains URLs
        if (urlStrings.count > 0) {
            // Convert the strings into NSURLs and save in a new array
            NSMutableArray <NSURL *> * urls = [NSMutableArray arrayWithCapacity:urlStrings.count];
            for (NSString * urlString in urlStrings) {
                // @c URLWithString may return @c nil, so check before appending to the array
                NSURL * url = [NSURL URLWithString:urlString];
                if (url != nil) {
                    [urls addObject:url];
                }
            }
            self.impressionTrackingURLs = urls;
        } else {
            // If the array does not contain URLs, take the old `x-imptracker` URL and save that into an array instead.
            // URL may be @c nil, so check before inserting into the array.
            NSURL * impressionTrackingURL = [self URLFromMetadata:metadata forKey:kImpressionTrackerMetadataKey];
            if (impressionTrackingURL != nil) {
                self.impressionTrackingURLs = @[impressionTrackingURL];
            }
        }

        // rewarded video

        // Attempt to parse the multiple currency Metadata first since this will take
        // precedence over the older single currency approach.
        self.availableRewards = [self parseAvailableRewardsFromMetadata:metadata];
        if (self.availableRewards != nil) {
            // Multiple currencies exist. We will select the first entry in the list
            // as the default selected reward.
            if (self.availableRewards.count > 0) {
                self.selectedReward = self.availableRewards[0];
            }
            // In the event that the list of available currencies is empty, we will
            // follow the behavior from the single currency approach and create an unspecified reward.
            else {
                MPRewardedVideoReward * defaultReward = [[MPRewardedVideoReward alloc] initWithCurrencyType:kMPRewardedVideoRewardCurrencyTypeUnspecified amount:@(kMPRewardedVideoRewardCurrencyAmountUnspecified)];
                self.availableRewards = [NSArray arrayWithObject:defaultReward];
                self.selectedReward = defaultReward;
            }
        }
        // Multiple currencies are not available; attempt to process single currency
        // metadata.
        else {
            NSString *currencyName = [metadata objectForKey:kRewardedVideoCurrencyNameMetadataKey] ?: kMPRewardedVideoRewardCurrencyTypeUnspecified;

            NSNumber *currencyAmount = [self adAmountFromMetadata:metadata key:kRewardedVideoCurrencyAmountMetadataKey];
            if (currencyAmount.integerValue <= 0) {
                currencyAmount = @(kMPRewardedVideoRewardCurrencyAmountUnspecified);
            }

            MPRewardedVideoReward * reward = [[MPRewardedVideoReward alloc] initWithCurrencyType:currencyName amount:currencyAmount];
            self.availableRewards = [NSArray arrayWithObject:reward];
            self.selectedReward = reward;
        }

        self.rewardedVideoCompletionUrl = [metadata objectForKey:kRewardedVideoCompletionUrlMetadataKey];

        // rewarded playables
        self.rewardedPlayableDuration = [self timeIntervalFromMetadata:metadata forKey:kRewardedPlayableDurationMetadataKey];
        self.rewardedPlayableShouldRewardOnClick = [[metadata objectForKey:kRewardedPlayableRewardOnClickMetadataKey] boolValue];

        // clickthrough experiment
        self.clickthroughExperimentBrowserAgent = [self clickthroughExperimentVariantFromMetadata:metadata forKey:kClickthroughExperimentBrowserAgent];
        [MOPUBExperimentProvider setDisplayAgentFromAdServer:self.clickthroughExperimentBrowserAgent];

        // viewability
        NSInteger disabledViewabilityValue = [metadata mp_integerForKey:kViewabilityDisableMetadataKey];

        if (disabledViewabilityValue != 0 &&
            disabledViewabilityValue >= MPViewabilityOptionNone &&
            disabledViewabilityValue <= MPViewabilityOptionAll) {
            MPViewabilityOption vendorsToDisable = (MPViewabilityOption)disabledViewabilityValue;
            [MPViewabilityTracker disableViewability:vendorsToDisable];
        }

        // advanced bidding
        self.advancedBidPayload = [metadata objectForKey:kAdvancedBiddingMarkupMetadataKey];
    }
    return self;
}

- (Class)setUpCustomEventClassFromMetadata:(NSDictionary *)metadata
{
    NSString *customEventClassName = [metadata objectForKey:kCustomEventClassNameMetadataKey];

    NSMutableDictionary *convertedCustomEvents = [NSMutableDictionary dictionary];
    if (self.adType == MPAdTypeBanner) {
        [convertedCustomEvents setObject:@"MPGoogleAdMobBannerCustomEvent" forKey:@"admob_native"];
        [convertedCustomEvents setObject:@"MPMillennialBannerCustomEvent" forKey:@"millennial_native"];
        [convertedCustomEvents setObject:@"MPHTMLBannerCustomEvent" forKey:@"html"];
        [convertedCustomEvents setObject:@"MPMRAIDBannerCustomEvent" forKey:@"mraid"];
        [convertedCustomEvents setObject:@"MOPUBNativeVideoCustomEvent" forKey:@"json_video"];
        [convertedCustomEvents setObject:@"MPMoPubNativeCustomEvent" forKey:@"json"];
    } else if (self.adType == MPAdTypeInterstitial) {
        [convertedCustomEvents setObject:@"MPGoogleAdMobInterstitialCustomEvent" forKey:@"admob_full"];
        [convertedCustomEvents setObject:@"MPMillennialInterstitialCustomEvent" forKey:@"millennial_full"];
        [convertedCustomEvents setObject:@"MPHTMLInterstitialCustomEvent" forKey:@"html"];
        [convertedCustomEvents setObject:@"MPMRAIDInterstitialCustomEvent" forKey:@"mraid"];
        [convertedCustomEvents setObject:@"MPMoPubRewardedVideoCustomEvent" forKey:@"rewarded_video"];
        [convertedCustomEvents setObject:@"MPMoPubRewardedPlayableCustomEvent" forKey:@"rewarded_playable"];
    }
    if ([convertedCustomEvents objectForKey:self.networkType]) {
        customEventClassName = [convertedCustomEvents objectForKey:self.networkType];
    }

    Class customEventClass = NSClassFromString(customEventClassName);

    if (customEventClassName && !customEventClass) {
        MPLogWarn(@"Could not find custom event class named %@", customEventClassName);
    }

    return customEventClass;
}



- (NSDictionary *)customEventClassDataFromMetadata:(NSDictionary *)metadata
{
    NSDictionary *result = [self dictionaryFromMetadata:metadata forKey:kCustomEventClassDataMetadataKey];
    if (!result) {
        result = [self dictionaryFromMetadata:metadata forKey:kNativeSDKParametersMetadataKey];
    }
    return result;
}


- (BOOL)hasPreferredSize
{
    return (self.preferredSize.width > 0 && self.preferredSize.height > 0);
}

- (NSString *)adResponseHTMLString
{
    if (!_adResponseHTMLString) {
        self.adResponseHTMLString = [[NSString alloc] initWithData:self.adResponseData
                                                           encoding:NSUTF8StringEncoding];
    }

    return _adResponseHTMLString;
}

- (NSString *)clickDetectionURLPrefix
{
    return self.interceptURLPrefix.absoluteString ? self.interceptURLPrefix.absoluteString : @"";
}

- (NSURL *)afterLoadUrlWithLoadDuration:(NSTimeInterval)duration loadResult:(MPAfterLoadResult)result
{
    // No URL to generate
    if (self.afterLoadUrlWithMacros == nil || self.afterLoadUrlWithMacros.length == 0) {
        return nil;
    }

    // Generate the ad server value from the enumeration. If the result type failed to
    // match, we should not process this any further.
    NSString * resultString = nil;
    switch (result) {
        case MPAfterLoadResultError: resultString = @"error"; break;
        case MPAfterLoadResultTimeout: resultString = @"timeout"; break;
        case MPAfterLoadResultAdLoaded: resultString = @"ad_loaded"; break;
        case MPAfterLoadResultMissingAdapter: resultString = @"missing_adapter"; break;
        default: return nil;
    }

    // Convert the duration to milliseconds
    NSString * durationMs = [NSString stringWithFormat:@"%llu", (unsigned long long)(duration * 1000)];

    // Replace the macros
    NSString * expandedUrl = [self.afterLoadUrlWithMacros stringByReplacingOccurrencesOfString:AFTER_LOAD_DURATION_MACRO withString:durationMs];
    expandedUrl = [expandedUrl stringByReplacingOccurrencesOfString:AFTER_LOAD_RESULT_MACRO withString:resultString];

    return [NSURL URLWithString:expandedUrl];
}

#pragma mark - Private

- (MPAdType)adTypeFromMetadata:(NSDictionary *)metadata
{
    NSString *adTypeString = [metadata objectForKey:kAdTypeMetadataKey];

    if ([adTypeString isEqualToString:@"interstitial"] || [adTypeString isEqualToString:@"rewarded_video"] || [adTypeString isEqualToString:@"rewarded_playable"]) {
        return MPAdTypeInterstitial;
    } else if (adTypeString &&
               [metadata objectForKey:kOrientationTypeMetadataKey]) {
        return MPAdTypeInterstitial;
    } else if (adTypeString) {
        return MPAdTypeBanner;
    } else {
        return MPAdTypeUnknown;
    }
}

- (NSString *)networkTypeFromMetadata:(NSDictionary *)metadata
{
    NSString *adTypeString = [metadata objectForKey:kAdTypeMetadataKey];
    if ([adTypeString isEqualToString:@"interstitial"]) {
        return [metadata objectForKey:kInterstitialAdTypeMetadataKey];
    } else {
        return adTypeString;
    }
}

- (NSURL *)URLFromMetadata:(NSDictionary *)metadata forKey:(NSString *)key
{
    NSString *URLString = [metadata objectForKey:key];
    return URLString ? [NSURL URLWithString:URLString] : nil;
}

- (NSDictionary *)dictionaryFromMetadata:(NSDictionary *)metadata forKey:(NSString *)key
{
    NSData *data = [(NSString *)[metadata objectForKey:key] dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *JSONFromMetadata = nil;
    if (data) {
        JSONFromMetadata = [NSJSONSerialization mp_JSONObjectWithData:data options:NSJSONReadingMutableContainers clearNullObjects:YES error:nil];
    }
    return JSONFromMetadata;
}

- (NSTimeInterval)refreshIntervalFromMetadata:(NSDictionary *)metadata
{
    NSTimeInterval interval = [metadata mp_doubleForKey:kRefreshTimeMetadataKey defaultValue:MINIMUM_REFRESH_INTERVAL];
    if (interval < MINIMUM_REFRESH_INTERVAL) {
        interval = MINIMUM_REFRESH_INTERVAL;
    }
    return interval;
}

- (NSTimeInterval)timeIntervalFromMetadata:(NSDictionary *)metadata forKey:(NSString *)key
{
    NSTimeInterval interval = [metadata mp_doubleForKey:key defaultValue:-1];
    return interval;
}

- (NSTimeInterval)timeIntervalFromMsmetadata:(NSDictionary *)metadata forKey:(NSString *)key
{
    NSTimeInterval interval = [metadata mp_doubleForKey:key defaultValue:-1];
    if (interval >= 0) {
        interval /= 1000.0f;
    }
    return interval;
}

- (NSInteger)percentFromMetadata:(NSDictionary *)metadata forKey:(NSString *)key
{
    return [metadata mp_integerForKey:key defaultValue:-1];

}

- (NSNumber *)adAmountFromMetadata:(NSDictionary *)metadata key:(NSString *)key
{
    NSInteger amount = [metadata mp_integerForKey:key defaultValue:-1];
    return @(amount);
}

- (MPInterstitialOrientationType)orientationTypeFromMetadata:(NSDictionary *)metadata
{
    NSString *orientation = [metadata objectForKey:kOrientationTypeMetadataKey];
    if ([orientation isEqualToString:@"p"]) {
        return MPInterstitialOrientationTypePortrait;
    } else if ([orientation isEqualToString:@"l"]) {
        return MPInterstitialOrientationTypeLandscape;
    } else {
        return MPInterstitialOrientationTypeAll;
    }
}

#if MP_HAS_NATIVE_PACKAGE
- (NSDictionary *)nativeVideoTrackersFromMetadata:(NSDictionary *)metadata key:(NSString *)key
{
    NSDictionary *dictFromMetadata = [self dictionaryFromMetadata:metadata forKey:key];
    if (!dictFromMetadata) {
        return nil;
    }
    NSMutableDictionary *videoTrackerDict = [NSMutableDictionary new];
    NSArray *events = dictFromMetadata[kNativeVideoTrackerEventsMetadataKey];
    NSArray *urls = dictFromMetadata[kNativeVideoTrackerUrlsMetadataKey];
    NSSet *supportedEvents = [NSSet setWithObjects:MPVASTTrackingEventTypeStart, MPVASTTrackingEventTypeFirstQuartile, MPVASTTrackingEventTypeMidpoint,  MPVASTTrackingEventTypeThirdQuartile, MPVASTTrackingEventTypeComplete, nil];
    for (NSString *event in events) {
        if (![supportedEvents containsObject:event]) {
            continue;
        }
        [self setVideoTrackers:videoTrackerDict event:event urls:urls];
    }
    if (videoTrackerDict.count == 0) {
        return nil;
    }
    return videoTrackerDict;
}

- (void)setVideoTrackers:(NSMutableDictionary *)videoTrackerDict event:(NSString *)event urls:(NSArray *)urls {
    NSMutableArray *trackers = [NSMutableArray new];
    for (NSString *url in urls) {
        if ([url rangeOfString:kNativeVideoTrackerUrlMacro].location != NSNotFound) {
            NSString *trackerUrl = [url stringByReplacingOccurrencesOfString:kNativeVideoTrackerUrlMacro withString:event];
            NSDictionary *dict = @{kNativeVideoTrackerEventDictionaryKey:event, kNativeVideoTrackerTextDictionaryKey:trackerUrl};
            MPVASTTrackingEvent *tracker = [[MPVASTTrackingEvent alloc] initWithDictionary:dict];
            [trackers addObject:tracker];
        }
    }
    if (trackers.count > 0) {
        videoTrackerDict[event] = trackers;
    }
}

#endif

- (NSArray *)parseAvailableRewardsFromMetadata:(NSDictionary *)metadata {
    // The X-Rewarded-Currencies Metadata key doesn't exist. This is probably
    // not a rewarded ad.
    NSDictionary * currencies = [metadata objectForKey:kRewardedCurrenciesMetadataKey];
    if (currencies == nil) {
        return nil;
    }

    // Either the list of available rewards doesn't exist or is empty.
    // This is an error.
    NSArray * rewards = [currencies objectForKey:@"rewards"];
    if (rewards.count == 0) {
        MPLogError(@"No available rewards found.");
        return nil;
    }

    // Parse the list of JSON rewards into objects.
    NSMutableArray * availableRewards = [NSMutableArray arrayWithCapacity:rewards.count];
    [rewards enumerateObjectsUsingBlock:^(NSDictionary * rewardDict, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString * name = rewardDict[@"name"] ?: kMPRewardedVideoRewardCurrencyTypeUnspecified;
        NSNumber * amount = rewardDict[@"amount"] ?: @(kMPRewardedVideoRewardCurrencyAmountUnspecified);

        MPRewardedVideoReward * reward = [[MPRewardedVideoReward alloc] initWithCurrencyType:name amount:amount];
        [availableRewards addObject:reward];
    }];

    return availableRewards;
}

- (MOPUBDisplayAgentType)clickthroughExperimentVariantFromMetadata:(NSDictionary *)metadata forKey:(NSString *)key
{
    NSInteger variant = [metadata mp_integerForKey:key];
    if (variant > kMaximumVariantForClickthroughExperiment) {
        variant = -1;
    }

    return variant;
}

- (BOOL)visibleImpressionTrackingEnabled
{
    if (self.impressionMinVisibleTimeInSec < 0 || self.impressionMinVisiblePixels <= 0) {
        return NO;
    }
    return YES;
}

@end
