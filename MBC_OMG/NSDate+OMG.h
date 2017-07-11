//
//  NSDate+OMG.h
//  MBC_OMG
//
//  Created by SegunLee on 2017. 3. 15..
//  Copyright © 2017년 SegunLee. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (OMG)

+ (NSDate *)dateWithYear:(NSInteger)year month:(NSInteger)month day:(NSInteger)day;
- (NSString *)omgyyyyMMdd;
- (NSDate *)omgAddDay:(NSInteger)day;
- (NSString *)weekDay;

@end
