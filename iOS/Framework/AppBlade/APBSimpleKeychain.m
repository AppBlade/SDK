//
//  SimpleKeychain.m
//  AppBlade
//
//  Created by jkaufman on 3/23/11.
//  Copyright 2011 AppBlade. All rights reserved.
//
#import "APBSimpleKeychain.h"
#import "AppBladeLogging.h"

#import <Security/Security.h>

@interface APBSimpleKeychain ()
+(BOOL)keychainInconsistencyTest:(BOOL)secondTry;


@end

@implementation APBSimpleKeychain

+(void)sanitizeKeychain
{
    if([self keychainInconsistencyExists])
    {
        [self deleteLocalKeychain];
    }
}


//SecKeychainGetStatus is a mac os only call,
//in fact all of SecKeychainStatus seems to be missing
//we gotta do this thing manually
+(BOOL)hasKeychainAccess
{
    //test with some dummy data, we need to be able to write, read, and remove.
    OSStatus keychainErrorCode = noErr; //
    NSString *keychainInterimCodeLabel = @"";

    OSStatus keychainInterimCode = noErr;
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:@"AppBladeKeychainTest"];

    CFDataRef keyData = NULL;
    
    //I only care about the first error code we hit
    //test writing
    SecItemDelete((__bridge CFDictionaryRef)keychainQuery);
    [keychainQuery setObject:[NSKeyedArchiver archivedDataWithRootObject:@"Delete This Thing"] forKey:(__bridge id)kSecValueData];
    keychainInterimCode = SecItemAdd((__bridge CFDictionaryRef)keychainQuery, NULL);
    keychainErrorCode = keychainInterimCode;
    keychainInterimCodeLabel = (keychainErrorCode == noErr) ? keychainInterimCodeLabel : @"writing";
    
    //test reading
    keychainInterimCode = SecItemCopyMatching((__bridge CFDictionaryRef)keychainQuery, (CFTypeRef *)&keyData);
    keychainErrorCode = (keychainErrorCode != noErr) ? keychainErrorCode : keychainInterimCode;
    keychainInterimCodeLabel = (keychainErrorCode == noErr || [keychainInterimCodeLabel length] != 0) ? keychainInterimCodeLabel : @"reading";
    if (keyData) CFRelease(keyData);

    //test deleting
    keychainQuery = [self getKeychainQuery:@"AppBladeKeychainTest"];
    keychainInterimCode = SecItemDelete((__bridge CFDictionaryRef)keychainQuery);
    keychainErrorCode = (keychainErrorCode != noErr) ? keychainErrorCode : keychainInterimCode;
    keychainInterimCodeLabel = (keychainErrorCode == noErr || [keychainInterimCodeLabel length] != 0) ? keychainInterimCodeLabel : @"deleting";
    
    // If the keychain item already exists, modify it:
    if (keychainErrorCode == noErr)
    {
        return TRUE;
    }else{
        // If the keychain item already exists, modify it:
        NSLog(@"Keychain error occured during keychain %@ test (and possibly other places, but occurred there first): %d : %@",
                                keychainInterimCodeLabel,
                                (int)keychainErrorCode,
                                [APBSimpleKeychain errorMessageFromCode:keychainErrorCode]);
        NSLog(@"The AppBlade SDK needs keychain access to store credentials.");
        return FALSE;
    }
}

+(BOOL)keychainInconsistencyExists
{
    return [self keychainInconsistencyTest:NO];
}


+(BOOL)keychainInconsistencyTest:(BOOL)secondTry
{
//test the keychain on the current app
    //test with some dummy data, we need to be able to write, read, and remove.
    OSStatus keychainErrorCode = noErr; //
    NSString *keychainInterimCodeLabel = @"";
    
    OSStatus keychainInterimCode = noErr;
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:@"AppBladeKeychainTest"];
    
    CFDataRef keyData = NULL;
    
    //I only care about the first error code we hit
    //test writing
    SecItemDelete((__bridge CFDictionaryRef)keychainQuery);
    [keychainQuery setObject:[NSKeyedArchiver archivedDataWithRootObject:@"Delete This Thing"] forKey:(__bridge id)kSecValueData];
    keychainInterimCode = SecItemAdd((__bridge CFDictionaryRef)keychainQuery, NULL);
    keychainErrorCode = keychainInterimCode;
    keychainInterimCodeLabel = (keychainErrorCode != noErr) ? keychainInterimCodeLabel : @"writing";
    
    //test reading
    keychainInterimCode = SecItemCopyMatching((__bridge CFDictionaryRef)keychainQuery, (CFTypeRef *)&keyData);
    keychainErrorCode = (keychainErrorCode != noErr) ? keychainErrorCode : keychainInterimCode;
    keychainInterimCodeLabel = (keychainErrorCode != noErr) ? keychainInterimCodeLabel : @"reading";
    if (keyData) CFRelease(keyData);
    
    //test deleting
    keychainQuery = [self getKeychainQuery:@"AppBladeKeychainTest"];
    keychainInterimCode = SecItemDelete((__bridge CFDictionaryRef)keychainQuery);
    keychainErrorCode = (keychainErrorCode != noErr) ? keychainErrorCode : keychainInterimCode;
    keychainInterimCodeLabel = (keychainErrorCode != noErr) ? keychainInterimCodeLabel : @"deleting";
    if (keychainErrorCode == noErr)
    {
        return TRUE;
    }
    else
    {
        // If the keychain item already exists, modify it:
        NSLog(@"Keychain error occured during keychain %@ test: %d : %@", keychainInterimCodeLabel, (int)keychainErrorCode, [APBSimpleKeychain errorMessageFromCode:keychainErrorCode]);
        NSLog(@"The AppBlade SDK needs keychain access to store credentials.");
        if(secondTry){
            NSLog(@"We've confirmed this fails twice in a row.");
            return FALSE;
        }else{
            NSLog(@"Let's try one more time.");
            return [self keychainInconsistencyTest:YES];
        }
    }
}

+(NSString*) errorMessageFromCode:(OSStatus)keychainErrorCode
{
    //        errSecSuccess                = 0,       /* No error. */
    //        errSecUnimplemented          = -4,      /* Function or operation not implemented. */
    //        errSecParam                  = -50,     /* One or more parameters passed to a function where not valid. */
    //        errSecAllocate               = -108,    /* Failed to allocate memory. */
    //        errSecNotAvailable           = -25291,	/* No keychain is available. You may need to restart your computer. */
    //        errSecDuplicateItem          = -25299,	/* The specified item already exists in the keychain. */
    //        errSecItemNotFound           = -25300,	/* The specified item could not be found in the keychain. */
    //        errSecInteractionNotAllowed  = -25308,	/* User interaction is not allowed. */
    //        errSecDecode                 = -26275,  /* Unable to decode the provided data. */
    //        errSecAuthFailed             = -25293,	/* The user name or passphrase you entered is not correct. */
    // -34018 client has neither application-identifier nor keychain-access-groups entitlements

        NSString *errorMessage = @"";
        //SecCopyErrorMessageString doesn't work in iOS! Consternation!
        switch (keychainErrorCode) {
            case errSecSuccess:
                errorMessage = @"\"No error.\" Wait. What? ";
                break;
            case errSecUnimplemented:
                errorMessage = @"Function or operation not implemented.";
                break;
            case errSecParam:
                errorMessage = @"One or more parameters passed to a function where not valid.";
                break;
            case errSecAllocate:
                errorMessage = @"Failed to allocate memory.";
                break;
            case errSecNotAvailable:
                errorMessage = @"No keychain is available. You may need to restart your device.";
                break;
            case errSecDuplicateItem:
                errorMessage = @"The specified item already exists in the keychain.";
                break;
            case errSecItemNotFound:
                errorMessage = @"The specified item could not be found in the keychain.";
                break;
            case errSecInteractionNotAllowed:
                errorMessage = @"User interaction is not allowed.";
                break;
            case errSecDecode:
                errorMessage = @"Unable to decode the provided data.";
                break;
            case -34018:
                errorMessage = @"client has neither application-identifier nor keychain-access-groups entitlements";
                break;
            default:
                errorMessage = @"(unknown error)";
                break;
        } //Not using the AppBlade Logs here because this is a CRITICAL error that should not be kept quiet.
    return errorMessage;
}


//This is obviously a very dangerous function. Use it as you would an atom bomb.
+(void)deleteLocalKeychain
{
    for (id secclass in @[
         (__bridge id)kSecClassGenericPassword,
         (__bridge id)kSecClassInternetPassword,
         (__bridge id)kSecClassCertificate,
         (__bridge id)kSecClassKey,
         (__bridge id)kSecClassIdentity]) {
        NSMutableDictionary *query = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                      secclass, (__bridge id)kSecClass,
                                      nil];
        
        SecItemDelete((__bridge CFDictionaryRef)query);
    }
}

// Returns the keychain request dictionary for a SimpleKeychain entry.
+ (NSMutableDictionary *)getKeychainQuery:(NSString *)service
{
    //NSAssert(service != nil, @"service must not be nil");
    //kSecClassGenericPassword attributes
    // kSecAttrAccessible
    // kSecAttrAccount
    // kSecAttrService
    // kSecAttrAccessGroup
    // kSecAttrCreationDate      //read only
    // kSecAttrModificationDate  //read only
    // kSecAttrDescription
    // kSecAttrComment
    // kSecAttrCreator
    // kSecAttrType
    // kSecAttrLabel
    // kSecAttrIsInvisible
    // kSecAttrIsNegative
    // kSecAttrGeneric
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:
            (__bridge id)kSecClassGenericPassword, (__bridge id)kSecClass,
            service, (__bridge id)kSecAttrService,
            service, (__bridge id)kSecAttrAccount,
            (__bridge id)kSecAttrAccessibleAfterFirstUnlock, (__bridge id)kSecAttrAccessible, // Keychain must be unlocked to access this value. It will persist across backups.
            nil];
    
}

// Accepts service name and NSCoding-complaint data object. Automatically overwrites if something exists.
//Returns true on success
+ (BOOL)save:(NSString *)service data:(id)data
{
    NSError *errorCheck = nil;
    BOOL result = [APBSimpleKeychain save:service data:data error:&errorCheck];
    if(errorCheck)
        NSLog(@"Save attempt to keychain failed : %@", [errorCheck description]);

    return result;
}

+ (BOOL)save:(NSString *)service data:(id)data error:(NSError * __autoreleasing *)error
{
    
    BOOL wasSuccessful = YES;
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:service];
    OSStatus resultCode = SecItemDelete((__bridge CFDictionaryRef)keychainQuery);
    [keychainQuery setObject:[NSKeyedArchiver archivedDataWithRootObject:data] forKey:(__bridge id)kSecValueData];
    resultCode =  SecItemAdd((__bridge CFDictionaryRef)keychainQuery, NULL);
    if(resultCode != noErr){
        NSMutableString *errorMsg = [[APBSimpleKeychain errorMessageFromCode:resultCode] mutableCopy];
        if(resultCode == errSecDuplicateItem){
            id dataExistenceCheck = [APBSimpleKeychain load:service];
            [errorMsg appendFormat:@"This exists instead: %@", dataExistenceCheck];
        }
        
        * error = [NSError errorWithDomain:@"APBSimpleKeychain"
                                      code:(int)resultCode
                                  userInfo:@{errorMsg  : NSLocalizedDescriptionKey }];
         wasSuccessful = NO;
    }else{
        wasSuccessful = YES;
    }
    
    return wasSuccessful;
}

// Returns an object inflated from the data stored in the keychain entry for the given service.
+ (id)load:(NSString *)service
{
    NSError *errorCheck = nil;
    id result = [APBSimpleKeychain load:service error:&errorCheck];
    if(errorCheck)
        NSLog(@"Load from keychain attempt failed : %@", [errorCheck description]);
    return result;
}

+ (id)load:(NSString *)service error:(NSError * __autoreleasing *)error
{
    id ret = nil;
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:service];
    [keychainQuery setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    [keychainQuery setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
    
    CFDataRef keyData = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)keychainQuery, (CFTypeRef *)&keyData) == noErr) {
        @try {
            ret = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)keyData];
            if(ret == nil){
                * error = [NSError errorWithDomain:@"APBSimpleKeychain"
                                              code:404
                                          userInfo:@{@"Keychain data not found." : NSLocalizedDescriptionKey }];
            }
        }
        @catch (NSException *e) {
            NSString *errMsg = [NSString stringWithFormat:@"Unarchive of %@ failed: %@", service, e];
            * error = [NSError errorWithDomain:@"APBSimpleKeychain"
                                          code:500
                                      userInfo:@{ errMsg : NSLocalizedDescriptionKey }];
        }
        @finally {}
    }
    
    if (keyData) CFRelease(keyData);
    return ret;
}

// Removes the entry for the given service from keychain.
+ (BOOL)delete:(NSString *)service
{
    NSError *errorCheck = nil;
    BOOL result = [APBSimpleKeychain delete:service error:&errorCheck];
    if(errorCheck)
        NSLog(@"Load from keychain attempt failed : %@", [errorCheck description]);
    return result;
}

+ (BOOL)delete:(NSString *)service error:(NSError * __autoreleasing *)error
{
    BOOL wasSuccessful = YES;
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:service];
    OSStatus resultCode = SecItemDelete((__bridge CFDictionaryRef) keychainQuery);
    if(resultCode != noErr){
        NSString *errMsg = [NSString stringWithFormat:@"Error deleting from keychain: %@", [APBSimpleKeychain errorMessageFromCode:resultCode]];
        * error = [NSError errorWithDomain:@"APBSimpleKeychain"
                                      code:(int)resultCode
                                  userInfo:@{errMsg  : NSLocalizedDescriptionKey }];
        wasSuccessful = NO;
    }else{
        wasSuccessful = YES;
    }
    return wasSuccessful;
}




@end
