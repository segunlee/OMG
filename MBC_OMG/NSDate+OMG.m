//
//  NSDate+OMG.m
//  MBC_OMG
//
//  Created by SegunLee on 2017. 3. 15..
//  Copyright © 2017년 SegunLee. All rights reserved.
//

#import "NSDate+OMG.h"

@implementation NSDate (OMG)

+ (NSDate *)dateWithYear:(NSInteger)year month:(NSInteger)month day:(NSInteger)day {
    NSCalendar *calendar  = [NSCalendar autoupdatingCurrentCalendar];
    NSDateComponents *comp = [[NSDateComponents alloc] init];
    comp.year = year;
    comp.month = month;
    comp.day = day;
    comp.hour = 0;
    comp.minute = 0;
    comp.second = 0;
    return [calendar dateFromComponents:comp];
}

- (NSString *)omgyyyyMMdd {
    NSCalendar *calendar = [NSCalendar autoupdatingCurrentCalendar];
    calendar.timeZone = [NSTimeZone systemTimeZone];
    calendar.locale = [NSLocale currentLocale];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setLocale:[NSLocale currentLocale]];
    [formatter setDateFormat:@"yyyyMMdd"];
    return [formatter stringFromDate:self];
}

- (NSDate *)omgAddDay:(NSInteger)day {
    NSCalendar *calendar  = [NSCalendar autoupdatingCurrentCalendar];
    NSDateComponents *comp = [[NSDateComponents alloc] init];
    comp.day = day;
    return [calendar dateByAddingComponents:comp toDate:self options:kNilOptions];
}

- (NSString *)weekDay {
    NSCalendar *calendar  = [NSCalendar autoupdatingCurrentCalendar];
    switch ([calendar component:NSCalendarUnitWeekday fromDate:self]) {
        case 1:
            return @"일";
        case 2:
            return @"월";
        case 3:
            return @"화";
        case 4:
            return @"수";
        case 5:
            return @"목";
        case 6:
            return @"금";
        case 7:
            return @"토";
        default:
            return @"??";
    }
}

@end
