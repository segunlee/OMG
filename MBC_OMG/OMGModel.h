//
//  OMGModel.h
//  MBC_OMG
//
//  Created by SegunLee on 2017. 3. 15..
//  Copyright © 2017년 SegunLee. All rights reserved.
//

#import <Realm/Realm.h>

@interface OMGModel : RLMObject

@property NSString *name;
@property NSString *date;
@property NSString *url;
@property NSNumber<RLMInt> *lastPlayTime;
@property NSNumber<RLMBool> *played;
@property NSNumber<RLMInt> *leftPlayTime;

@end
RLM_ARRAY_TYPE(OMGModel)
