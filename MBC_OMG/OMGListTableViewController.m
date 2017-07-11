//
//  OMGListTableViewController.m
//  MBC_OMG
//
//  Created by SegunLee on 2017. 3. 15..
//  Copyright © 2017년 SegunLee. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Realm/Realm.h>
#import <UIView+Toast.h>
#import <EAMiniAudioPlayerView/EAMiniAudioPlayerView.h>
#import <StreamingKit/STKAudioPlayer.h>

#import "AppDelegate.h"
#import "OMGListTableViewController.h"
#import "OMGModel.h"
#import "NSDate+OMG.h"

#define Toast(a) [((AppDelegate *)[UIApplication sharedApplication].delegate).window makeToast:a];


@interface OMGListTableViewController () <STKAudioPlayerDelegate, UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) RLMRealm *realm;
@property (nonatomic, strong) RLMResults<OMGModel *> *sources;
@property (nonatomic, strong) STKAudioPlayer *audioPlayer;
@property (nonatomic, weak) IBOutlet EAMiniAudioPlayerView *playerView;
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, strong) OMGModel *playedModel;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation OMGListTableViewController

#pragma mark - LIFE CYCLE
- (void)viewDidLoad {
    [super viewDidLoad];
    
    _realm = [RLMRealm defaultRealm];
    _sources = [OMGModel allObjects];
    _audioPlayer = [[STKAudioPlayer alloc] init];
    _audioPlayer.delegate = self;
    
    [self dataCreate];
    [self playerViewHandle];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"CELL"];
    [self setupTimer];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setMode:AVAudioSessionModeDefault error:nil];
    [session setActive:YES error:nil];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(sessionDidInterrupt:) name:AVAudioSessionInterruptionNotification object:session];
    [center addObserver:self selector:@selector(audioHardwareRouteChanged:) name:AVAudioSessionRouteChangeNotification object:session];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSNumber *INDEX = [[NSUserDefaults standardUserDefaults] valueForKey:@"INDEX"];
            if (INDEX) {
                [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:INDEX.integerValue inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
            }
        });
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)sessionDidInterrupt:(NSNotification*)notification {
    // 인터럽트 정보
    NSNumber* interrptionType = [[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey];
    NSNumber* interrptionOption = [[notification userInfo] objectForKey:AVAudioSessionInterruptionOptionKey];
    
    switch(interrptionType.unsignedIntegerValue) {
            // 착신음 등의 인터럽트 생성
        case AVAudioSessionInterruptionTypeBegan:
            // 재생 중인 곡을 일시 중지
            [_audioPlayer pause];
            break;
            
            // 착신음 등의 인터럽트 종료
        case AVAudioSessionInterruptionTypeEnded:
            switch(interrptionOption.unsignedIntegerValue) {
                case AVAudioSessionInterruptionOptionShouldResume:
                    // 일시 정지 중인 곡을 재시작
                    [_audioPlayer resume];
                    break;
                default:
                    break;
            }
            break;
            
        default:
            break;
    }
}

- (void)audioHardwareRouteChanged:(NSNotification *)notification {
    if (_audioPlayer.currentlyPlayingQueueItemId) {
        [_audioPlayer pause];
    }
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event
{
    if (event.type == UIEventTypeRemoteControl) {
        switch (event.subtype) {
            case UIEventSubtypeRemoteControlPlay:
                if (_audioPlayer.currentlyPlayingQueueItemId) {
                    [_audioPlayer resume];
                }
                break;
            case UIEventSubtypeRemoteControlPause:
                [_audioPlayer pause];
                break;
            case UIEventSubtypeRemoteControlNextTrack:
                break;
            case UIEventSubtypeRemoteControlPreviousTrack:
                break;
            default:
                break;
        }
    }
}

- (IBAction)tenSecBack:(id)sender {
    if (_playedModel.lastPlayTime.floatValue > 0) {
        [_audioPlayer seekToTime:_audioPlayer.progress-10];
    }
}

- (IBAction)tenSecForward:(id)sender {
    if (_playedModel.lastPlayTime.floatValue > 0) {
        [_audioPlayer seekToTime:_audioPlayer.progress+10];
    }
}

#pragma mark - 
- (void)playerViewHandle {
    __weak typeof(self) wSelf = self;
    _playerView.doPlay = ^(id sender, bool isPlay) {
        if(isPlay)
        {
            [wSelf.audioPlayer resume];
        }
        else
        {
            [wSelf.audioPlayer pause];
        }
    };
}

- (void)setupTimer {
    _timer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)tick {
    
    if (!_audioPlayer)
    {
        _playerView.textLabel.text = nil;
        _playerView.playProgress = 0;
        _playerView.downloadProgress = 0;
        return;
    }
    
    if (_audioPlayer.currentlyPlayingQueueItemId == nil)
    {
        _playerView.textLabel.text = nil;
        _playerView.playProgress = 0;
        _playerView.downloadProgress = 0;
        return;
    }
    
    if (_audioPlayer.duration != 0)
    {
        _playerView.playProgress = _audioPlayer.progress / _audioPlayer.duration;
        _playerView.downloadProgress = _audioPlayer.progress / _audioPlayer.duration;
    }
    else
    {
        
    }
    
    _playerView.playButton.selected = _audioPlayer.state == STKAudioPlayerStatePlaying;
    
    if (_audioPlayer.state == STKAudioPlayerStatePlaying && _playedModel) {
        if (_audioPlayer.currentlyPlayingQueueItemId) {
            [_realm beginWriteTransaction];
            _playedModel.lastPlayTime = @(_audioPlayer.progress);
            _playedModel.leftPlayTime = @(_audioPlayer.duration - _audioPlayer.progress);
            [_realm commitWriteTransaction];
        }
    }
    
    [self reloadTableViewWithSelection];
}


- (void) audioPlayer:(STKAudioPlayer*)audioPlayer didStartPlayingQueueItemId:(NSObject*)queueItemId {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if (_playedModel.lastPlayTime.floatValue > 0) {
        [_audioPlayer seekToTime:_playedModel.lastPlayTime.floatValue];
    }
}

- (void) audioPlayer:(STKAudioPlayer*)audioPlayer didFinishBufferingSourceWithQueueItemId:(NSObject*)queueItemId {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void) audioPlayer:(STKAudioPlayer*)audioPlayer stateChanged:(STKAudioPlayerState)state previousState:(STKAudioPlayerState)previousState {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    switch (state) {
        case STKAudioPlayerStatePaused:
            if (_audioPlayer.currentlyPlayingQueueItemId) {
                [_realm beginWriteTransaction];
                _playedModel.lastPlayTime = @(_audioPlayer.progress);
                [_realm commitWriteTransaction];
            }
            break;
        default:
            break;
    }
}

- (void) audioPlayer:(STKAudioPlayer*)audioPlayer didFinishPlayingQueueItemId:(NSObject*)queueItemId withReason:(STKAudioPlayerStopReason)stopReason andProgress:(double)progress andDuration:(double)duration {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    switch (stopReason) {
        case STKAudioPlayerStopReasonEof:
        {
            [_realm beginWriteTransaction];
            _playedModel.played = @YES;
            _playedModel.lastPlayTime = @0;
            _playedModel.leftPlayTime = @0;
            [_realm commitWriteTransaction];
            [self reloadTableViewWithSelection];
        }
            break;
        case STKAudioPlayerStopReasonError:
        case STKAudioPlayerStopReasonNone:
        {
            if (progress == 0 && duration == 0) {
                [_realm beginWriteTransaction];
                _playedModel.played = @YES;
                _playedModel.lastPlayTime = @0;
                _playedModel.leftPlayTime = @-999;
                [_realm commitWriteTransaction];
                [self reloadTableViewWithSelection];
                NSString *msg = [NSString stringWithFormat:@"%@ 서비스 안됨", _playedModel.name];
                Toast(msg)
            }
        }
            break;
        default:
            break;
    }
}

- (void) audioPlayer:(STKAudioPlayer*)audioPlayer unexpectedError:(STKAudioPlayerErrorCode)errorCode {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void) audioPlayer:(STKAudioPlayer*)audioPlayer logInfo:(NSString*)line {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void) audioPlayer:(STKAudioPlayer*)audioPlayer didCancelQueuedItems:(NSArray*)queuedItems {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark - DATA CREATE
- (void)dataCreate {
    if ([[OMGModel allObjects] count] > 0) {
        Toast(@"Data has");
        return;
    }
    
    /*
        2010년 10월 18일~2011년 5월 8일
        http://podcastfile.imbc.gscdn.com/mp3/radio/podcast/dream/dream_20110203.mp3
    */
    Toast(@"Sync Start");
    NSDate *startDate = [NSDate dateWithYear:2010 month:10 day:18];
    NSDate *endDate = [NSDate dateWithYear:2011 month:5 day:8];
    NSDate *refDate = [startDate omgAddDay:-1];
    NSString *baseURLFormat = @"http://podcastfile.imbc.gscdn.com/mp3/radio/podcast/dream/dream_%@.mp3";
    
    [_realm beginWriteTransaction];
    
    BOOL gogo = YES;
    while (gogo) {
        refDate = [refDate omgAddDay:1];
        
        OMGModel *model = [[OMGModel alloc] init];
        model.name = [NSString stringWithFormat:@"%@ (%@)", [refDate omgyyyyMMdd], [refDate weekDay]];
        model.date = [refDate omgyyyyMMdd];
        model.url = [NSString stringWithFormat:baseURLFormat, [refDate omgyyyyMMdd]];
        model.lastPlayTime = @0;
        model.played = @NO;
        model.leftPlayTime = @-1;
        
        [_realm addObject:model];
        
        NSComparisonResult result = [refDate compare:endDate];
        gogo = result != NSOrderedSame;
    }
    
    [_realm commitWriteTransaction];
    Toast(@"Sync Finish");
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _sources.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CELL" forIndexPath:indexPath];
    
    OMGModel *model = [_sources objectAtIndex:indexPath.row];
    
    NSString *dpName = model.name;
    
    if ([self getNameWithKey:model.date]) {
        dpName = [self getNameWithKey:model.date];
    }
    
    cell.textLabel.text = [NSString stringWithFormat:@"%@ > %@", dpName, [self getMMSSWithValue:model.leftPlayTime.integerValue]];
    cell.textLabel.font = [UIFont systemFontOfSize:9.0f];
    if (model.played.boolValue) {
        cell.textLabel.textColor = [UIColor lightGrayColor];
    } else {
        cell.textLabel.textColor = [UIColor blueColor];
    }
    
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"INDEX"] integerValue] == indexPath.row) {
        cell.textLabel.textColor = [UIColor redColor];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_audioPlayer.currentlyPlayingQueueItemId) {
        [_realm beginWriteTransaction];
        _playedModel.lastPlayTime = @(_audioPlayer.progress);
        [_realm commitWriteTransaction];
    }
    
    
    _playedModel = [_sources objectAtIndex:indexPath.row];
    _playerView.textLabel.text = _playedModel.name;
    _playerView.playProgress = 0;
    
    [_audioPlayer clearQueue];
    [_audioPlayer play:_playedModel.url withQueueItemID:_playedModel.date];
    if (_playedModel.lastPlayTime.floatValue > 0) {
        [_audioPlayer seekToTime:_playedModel.lastPlayTime.floatValue];
    }
    
    [[NSUserDefaults standardUserDefaults] setValue:@(indexPath.row) forKey:@"INDEX"];
}

- (void)reloadTableViewWithSelection {
    NSIndexPath *indexPath = self.tableView.indexPathForSelectedRow;
    [self.tableView reloadData];
    [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
    
}

- (NSString *)getNameWithKey:(NSString *)key {
    
    NSDictionary *source = @{@"20101018" : @"101018(월) 옹달샘과 꿈꾸라 첫째날! 축하사절단 with UV(유브이) & 은지원 & 박슬기", @"20101019" : @"101019(화) 옹달샘과 꿈꾸라 둘째날! 축하사절단 with 김경진,오나미", @"20101020" : @"101020(수) 박새별의 OMG with 박새별", @"20101021" : @"101021(목) 화요비의 창작의 기쁨 with 화요비", @"20101022" : @"101022(금) UV와 공개방송 첫번째 빅매치! UV(유브이) Miss A(미스에이)", @"20101023" : @"101023(토) DJ 그까이꺼", @"20101024" : @"101024(일) 명사와의 만남", @"20101025" : @"101025(월) 옹달샘과 미정이", @"20101026" : @"101026(화) 명사와의 만남", @"20101027" : @"101027(수) 박새별의 OMG with 박새별", @"20101028" : @"101028(목) 화요비의 창작의 기쁨 with 화요비", @"20101029" : @"101029(금) UV와 공개방송 with UV(유브이)VS샤이니", @"20101030" : @"101030(토) DJ 그까이꺼", @"20101031" : @"101031(일) THE 뮤지", @"20101101" : @"101101(월) 옹달샘과 미정이", @"20101102" : @"101102(화) 어제 만난 그녀", @"20101103" : @"101103(수) 박새별의 OMG with 박새별", @"20101104" : @"101104(목) 화요비의 창작의 기쁨 with 화요비", @"20101105" : @"101105(금) UV와 공개방송 with UV(유브이)VS김장훈", @"20101106" : @"101106(토) DJ 그까이꺼", @"20101107" : @"101107(일) 명사와의 만남", @"20101108" : @"101108(월) 옹달샘과 미정이", @"20101110" : @"101110(수) 박새별의 OMG with 박새별", @"20101111" : @"101111(목) 화요비의 창작의 기쁨 with 화요비", @"20101112" : @"101112(금) UV와 공개방송 with UV(유브이)VS슈프림팀", @"20101113" : @"101113(토) DJ 그까이꺼", @"20101114" : @"101114(일) 명사와의 만남", @"20101115" : @"101115(월) 옹달샘과 미정이", @"20101116" : @"101116(화) 젊은이의 인기가요", @"20101117" : @"101117(수) 박새별의 OMG with 박새별", @"20101118" : @"101118(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진", @"20101119" : @"101119(금) UV와 공개방송 with UV(유브이)VS정엽", @"20101120" : @"101120(토) DJ 그까이꺼", @"20101121" : @"101121(일) 명사와의 만남", @"20101122" : @"101122(월) 옹달샘과 미정이", @"20101123" : @"101123(화) 사연과 신청곡", @"20101124" : @"101124(수) 실시간 사연 신청곡", @"20101125" : @"101125(목) 뜬금없는 11월특집! 옹달샘에게 보내는노래", @"20101126" : @"101126(금) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진1부", @"20101126" : @"101126(금) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진2부", @"20101127" : @"101127(토) DJ 그까이꺼", @"20101128" : @"101128(일) 명사와의 만남1부", @"20101129" : @"101129(월) 옹달샘과 미정이", @"20101130" : @"101130(화) 뮤지의 최신가요 With 뮤지", @"20101202" : @"101202(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진", @"20101203" : @"101203(금) UV와 공개방송 with UV(유브이)VS 장기하와 얼굴들", @"20101204" : @"101204(토) DJ 그까이꺼", @"20101205" : @"101205(일) 명사와의 만남1", @"20101205" : @"101205(일) 명사와의 만남2", @"20101206" : @"101206(월) 옹달샘과 미정이", @"20101207" : @"101207(화) 뮤지의 최신가요 With 뮤지", @"20101208" : @"101208(수) 박새별의 OMG with 박새별", @"20101209" : @"101209(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진", @"20101210" : @"101210(금) UV와 공개방송 with UV(유브이)VS 윤하", @"20101211" : @"101211(토) DJ 그까이꺼", @"20101212" : @"101212(일) 명사와의 만남 with 컴퓨터님", @"20101214" : @"101214(화) 뮤지의 최신가요 With 뮤지", @"20101215" : @"101215(수) 박새별의 OMG with 박새별", @"20101216" : @"101216(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진", @"20101217" : @"101217(금) UV와 공개방송 with UV(유브이)VS 아이유", @"20101218" : @"101218(토) DJ 그까이꺼", @"20101219" : @"101219(일) 명사와의 만남 with 루돌프 님", @"20101220" : @"101220(월) 옹달샘과 미정이", @"20101221" : @"101221(화) 뮤지의 최신가요 With 뮤지", @"20101222" : @"101222(수) 박새별의 OMG with 박새별", @"20101223" : @"101223(목) UV와 공개방송 with UV(유브이)VS 허각 & 김지수 & 션리", @"20101224" : @"101224(금) [VOD] 크리스마스이브특집 아빠는 뚜비뚜비다 with 아버지&옥상달빛&뮤지&박새별"};
    
    return source[key];
}

- (NSString *)getMMSSWithValue:(NSInteger)value {
    if (value == 0) {
        return @"0";
    }
    
    if (value == -1) {
        return @"재생안함";
    }
    
    if (value < -1) {
        return @"재생불가";
    }
    
    NSInteger min = value / 60;
    NSInteger left = value % 60;
    return [NSString stringWithFormat:@"%02ld:%02ld", min, left];
}

@end
