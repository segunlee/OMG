//
//  OMGListTableViewController.m
//  MBC_OMG
//
//  Created by SegunLee on 2017. 3. 15..
//  Copyright © 2017년 SegunLee. All rights reserved.
//

#import <MediaPlayer/MediaPlayer.h>
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

@property (nonatomic, weak) IBOutlet EAMiniAudioPlayerView *playerView;
@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UISlider *slider;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;


@property (nonatomic, strong) RLMRealm *realm;
@property (nonatomic, strong) RLMResults<OMGModel *> *sources;
@property (nonatomic, strong) STKAudioPlayer *audioPlayer;
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
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setMode:AVAudioSessionModeDefault error:nil];
    [session setActive:YES error:nil];
	
	[[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
	[self becomeFirstResponder];
    
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

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
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
			{
				NSIndexPath *indexPath = self.tableView.indexPathForSelectedRow;
				indexPath = [NSIndexPath indexPathForRow:indexPath.row+1 inSection:0];
				[self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionMiddle];
				[self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
			}
                break;
            case UIEventSubtypeRemoteControlPreviousTrack:
			{
				NSIndexPath *indexPath = self.tableView.indexPathForSelectedRow;
				indexPath = [NSIndexPath indexPathForRow:indexPath.row-1 inSection:0];
				[self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionMiddle];
				[self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
			}
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

- (IBAction)sliderSeek:(UISlider *)sender {
	[_audioPlayer seekToTime:sender.value];
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
    _timer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)tick {
    
    if (!_audioPlayer)
    {
        _playerView.textLabel.text = nil;
        _playerView.playProgress = 0;
        _playerView.downloadProgress = 0;
		_slider.value = 0;
		_slider.minimumValue = 0;
		_slider.maximumValue = 0;
		_timeLabel.text = nil;
        return;
    }
    
    if (_audioPlayer.currentlyPlayingQueueItemId == nil)
    {
        _playerView.textLabel.text = nil;
        _playerView.playProgress = 0;
        _playerView.downloadProgress = 0;
		_slider.value = 0;
		_slider.minimumValue = 0;
		_slider.maximumValue = 0;
		_timeLabel.text = nil;
        return;
    }
    
    if (_audioPlayer.duration != 0)
    {
        _playerView.playProgress = _audioPlayer.progress / _audioPlayer.duration;
        _playerView.downloadProgress = _audioPlayer.progress / _audioPlayer.duration;
		
		[_slider setValue:_audioPlayer.progress animated:YES];
		_slider.minimumValue = 0;
		_slider.maximumValue = _audioPlayer.duration;
		
		NSString *left = [self getMMSSWithValue:_audioPlayer.progress];
		NSString *right = [self getMMSSWithValue:_audioPlayer.duration];
		
		_timeLabel.text = [NSString stringWithFormat:@"%@ | %@", left, right];
		
		MPNowPlayingInfoCenter *infoCenter = [MPNowPlayingInfoCenter defaultCenter];
		
		NSInteger index = self.tableView.indexPathForSelectedRow.row;
		
		NSString *dpName = _sources[index].name;
		if ([self getNameWithKey:_sources[index].date]) {
			dpName = [self getNameWithKey:_sources[index].date];
		}
		
		[infoCenter setNowPlayingInfo:@{
			MPMediaItemPropertyTitle: dpName,
			MPMediaItemPropertyArtist: @"MBC 옹꾸라",
			MPNowPlayingInfoPropertyElapsedPlaybackTime: @(_audioPlayer.progress),
			MPMediaItemPropertyPlaybackDuration: @(_audioPlayer.duration),
			MPMediaItemPropertyArtwork: [[MPMediaItemArtwork alloc] initWithImage:[UIImage imageNamed:@"cover"]]
		}];
    }
    else
    {
		_slider.value = 0;
		_slider.minimumValue = 0;
		_slider.maximumValue = 0;
		_timeLabel.text = nil;
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
    
	if (stopReason == STKAudioPlayerStopReasonNone && (_playedModel.lastPlayTime.doubleValue - 3) < duration && _audioPlayer.progress != 0) {
		stopReason = STKAudioPlayerStopReasonEof;
	}
	
    switch (stopReason) {
        case STKAudioPlayerStopReasonEof:
        {
            [_realm beginWriteTransaction];
            _playedModel.played = @YES;
            _playedModel.lastPlayTime = @0;
            _playedModel.leftPlayTime = @0;
            [_realm commitWriteTransaction];
            [self reloadTableViewWithSelection];
			
			NSIndexPath *indexPath = self.tableView.indexPathForSelectedRow;
			indexPath = [NSIndexPath indexPathForRow:indexPath.row+1 inSection:0];
			[self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionMiddle];
			[self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
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
        http://podcastfile.imbc.gscdn.com/originaldata/dream/dream_20110203.mp3
	 
		http://www.mediafire.com/?9jkd34f83wm34
    */
    Toast(@"Sync Start");
    NSDate *startDate = [NSDate dateWithYear:2010 month:10 day:18];
    NSDate *endDate = [NSDate dateWithYear:2011 month:5 day:8];
    NSDate *refDate = [startDate omgAddDay:-1];
    NSString *baseURLFormat = @"http://podcastfile.imbc.gscdn.com/originaldata/dream/dream_%@.mp3";
    
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
    
    cell.textLabel.text = [NSString stringWithFormat:@"%@ %@ 📻 %@", model.date, dpName, [self getMMSSWithValue:model.leftPlayTime.integerValue]];
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
    return [NSString stringWithFormat:@"%02zd:%02zd", min, left];
}

- (NSString *)getNameWithKey:(NSString *)key {
    NSDictionary *dataSource = @{
                                 @"20101018" :  @"(월) 옹달샘과 꿈꾸라 첫째날! 축하사절단 with UV(유브이) & 은지원 & 박슬기",
                                 @"20101019" :  @"(화) 옹달샘과 꿈꾸라 둘째날! 축하사절단 with 김경진,오나미",
                                 @"20101020" :  @"(수) 박새별의 OMG with 박새별",
                                 @"20101021" :  @"(목) 화요비의 창작의 기쁨 with 화요비",
                                 @"20101022" :  @"(금) UV와 공개방송 첫번째 빅매치! UV(유브이) Miss A(미스에이)",
                                 @"20101023" :  @"(토) DJ 그까이꺼",
                                 @"20101024" :  @"(일) 명사와의 만남",
                                 @"20101025" :  @"(월) 옹달샘과 미정이",
                                 @"20101026" :  @"(화) 명사와의 만남",
                                 @"20101027" :  @"(수) 박새별의 OMG with 박새별",
                                 @"20101028" :  @"(목) 화요비의 창작의 기쁨 with 화요비",
                                 @"20101029" :  @"(금) UV와 공개방송 with UV(유브이)VS샤이니",
                                 @"20101030" :  @"(토) DJ 그까이꺼",
                                 @"20101031" :  @"(일) THE 뮤지",
                                 @"20101101" :  @"(월) 옹달샘과 미정이",
                                 @"20101102" :  @"(화) 어제 만난 그녀",
                                 @"20101103" :  @"(수) 박새별의 OMG with 박새별",
                                 @"20101104" :  @"(목) 화요비의 창작의 기쁨 with 화요비",
                                 @"20101105" :  @"(금) UV와 공개방송 with UV(유브이)VS김장훈",
                                 @"20101106" :  @"(토) DJ 그까이꺼",
                                 @"20101107" :  @"(일) 명사와의 만남",
                                 @"20101108" :  @"(월) 옹달샘과 미정이",
                                 @"20101110" :  @"(수) 박새별의 OMG with 박새별",
                                 @"20101111" :  @"(목) 화요비의 창작의 기쁨 with 화요비",
                                 @"20101112" :  @"(금) UV와 공개방송 with UV(유브이)VS슈프림팀",
                                 @"20101113" :  @"(토) DJ 그까이꺼",
                                 @"20101114" :  @"(일) 명사와의 만남",
                                 @"20101115" :  @"(월) 옹달샘과 미정이",
                                 @"20101116" :  @"(화) 젊은이의 인기가요",
                                 @"20101117" :  @"(수) 박새별의 OMG with 박새별",
                                 @"20101118" :  @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20101119" :  @"(금) UV와 공개방송 with UV(유브이)VS정엽",
                                 @"20101120" :  @"(토) DJ 그까이꺼",
                                 @"20101121" :  @"(일) 명사와의 만남",
                                 @"20101122" :  @"(월) 옹달샘과 미정이",
                                 @"20101123" :  @"(화) 사연과 신청곡",
                                 @"20101124" :  @"(수) 실시간 사연 신청곡",
                                 @"20101125" :  @"(목) 뜬금없는 11월특집! 옹달샘에게 보내는노래",
                                 @"20101126" :  @"(금) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진1부",
                                 @"20101126" :  @"(금) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진2부",
                                 @"20101127" :  @"(토) DJ 그까이꺼",
                                 @"20101128" :  @"(일) 명사와의 만남",
                                 @"20101129" :  @"(월) 옹달샘과 미정이",
                                 @"20101130" :  @"(화) 뮤지의 최신가요 With 뮤지",
                                 @"20101202" :  @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20101203" :  @"(금) UV와 공개방송 with UV(유브이)VS 장기하와 얼굴들",
                                 @"20101204" :  @"(토) DJ 그까이꺼",
                                 @"20101205" :  @"(일) 명사와의 만남1",
                                 @"20101205" :  @"(일) 명사와의 만남2",
                                 @"20101206" :  @"(월) 옹달샘과 미정이",
                                 @"20101207" :  @"(화) 뮤지의 최신가요 With 뮤지",
                                 @"20101208" :  @"(수) 박새별의 OMG with 박새별",
                                 @"20101209" :  @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20101210" :  @"(금) UV와 공개방송 with UV(유브이)VS 윤하",
                                 @"20101211" :  @"(토) DJ 그까이꺼",
                                 @"20101212" :  @"(일) 명사와의 만남 with 컴퓨터님",
                                 @"20101214" :  @"(화) 뮤지의 최신가요 With 뮤지",
                                 @"20101215" :  @"(수) 박새별의 OMG with 박새별",
                                 @"20101216" :  @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20101217" :  @"(금) UV와 공개방송 with UV(유브이)VS 아이유",
                                 @"20101217" :  @"UV와 공개방송 with UV(유브이)VS 아이유.mp3",
                                 @"20101217" :  @"[보이는 라디오] UV와 공개방송 with UV(유브이)VS 아이유",
                                 @"20101217" :  @"[VOD] UV와 공개방송 with UV(유브이)VS 아이유",
                                 @"20101217" :  @"[VOD] UV와 공개방송 with UV(유브이)VS 아이유",
                                 @"20101218" :  @"(토) DJ 그까이꺼",
                                 @"20101219" :  @"(일) 명사와의 만남 with 루돌프 님",
                                 @"20101220" :  @"(월) 옹달샘과 미정이",
                                 @"20101221" :  @"(화) 뮤지의 최신가요 With 뮤지",
                                 @"20101222" :  @"(수) 박새별의 OMG with 박새별",
                                 @"20101223" :  @"(목) UV와 공개방송 with UV(유브이)VS 허각 & 김지수 & 션리",
                                 @"20101224" :  @"(금) [VOD] 크리스마스이브특집 아빠는 뚜비뚜비다 with 아버지&옥상달빛&뮤지&박새별",
                                 @"20101224" :  @"(금) [VOD] 크리스마스이브특집 아빠는 뚜비뚜비다 with 아버지&옥상달빛&뮤지&박새별",
                                 @"20101224" :  @"(금) [VOD] 크리스마스이브특집 아빠는 뚜비뚜비다 with 아버지&옥상달빛&뮤지&박새별",
                                 @"20101224" :  @"(금) 크리스마스이브특집 아빠는 뚜비뚜비다 with 아버지&옥상달빛&뮤지&박새별",
                                 @"20101224" :  @"(금) [보이는 라디오] 크리스마스이브특집 아빠는 뚜비뚜비다 with 아버지&옥상달빛&뮤지&박새별",
                                 @"20101225" :  @"(토) DJ 그까이꺼",
                                 @"20101226" :  @"(일) 명사와의 만남 with 말레이곰(꼬마)님",
                                 @"20101227" :  @"(월) 옹달샘과 미정이",
                                 @"20101228" :  @"(화) 뮤지의 최신가요 With 뮤지",
                                 @"20101229" :  @"(수) 박새별의 OMG with 박새별",
                                 @"20101230" :  @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20101231" :  @"(금) UV와 공개방송 with 노홍철 & 윤종신 & 정엽 & 옹꾸라합창단",
                                 @"20101231" :  @"(금) UV와 공개방송 with 노홍철 & 윤종신 & 정엽 & 옹꾸라합창단1",
                                 @"20110101" :  @"(토) DJ 그까이꺼",
                                 @"20110102" :  @"(일) 명사와의 만남 with 명사님들",
                                 @"20110103" :  @"(월) 옹달샘과 미정이",
                                 @"20110104" :  @"(화) 뮤지의 최신가요 With 뮤지",
                                 @"20110105" :  @"(수) 문지애의 OMG with 문지애",
                                 @"20110106" :  @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20110107" :  @"(금) UV와 공개방송 with 시크릿",
                                 @"20110108" :  @"(토) DJ 그까이꺼",
                                 @"20110109" :  @"(일) 1부2부 그땐 미처 읽지 못했지 3부4부 명사와의 만남 with 토끼님",
                                 @"20110110" :  @"(월) 옹달샘과 미정이",
                                 @"20110111" :  @"(화) 뮤지의 최신가요 With 뮤지",
                                 @"20110112" :  @"(수) 레이디제인의 OMG with 레이디제인",
                                 @"20110113" :  @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20110114" :  @"(금) UV와 공개방송 with UV(유브이)VS 엠블랙",
                                 @"20110115" :  @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 엠블랙",
                                 @"20110115" :  @"(토) DJ 그까이꺼",
                                 @"20110116" :  @"(일) 명사와의 만남 with 거울님",
                                 @"20110117" :  @"(월) 옹달샘과 미정이",
                                 @"20110118" :  @"(화) 뮤지의 최신가요 With 뮤지",
                                 @"20110119" :  @"(수) 정인의 OMG with 정인",
                                 @"20110120" :  @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20110121" :  @"(금) UV와 공개방송 with UV(유브이)VS 임정희 & 산이",
                                 @"20110121" :  @"(금) [보이는 라디오] UV와 공개방송 with UV(유브이)VS 임정희 & 산이",
                                 @"20110121" :  @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 임정희 & 산이",
                                 @"20110121" :  @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 임정희 & 산이",
                                 @"20110122" :  @"(토) DJ 그까이꺼",
                                 @"20110123" :  @"(일) 명사와의 만남 with 소주 님",
                                 @"20110124" :  @"(월) 옹달샘과 미정이",
                                 @"20110125" :  @"(화) 100일특집 - 옹꾸라코드 With 윤종신,고영욱",
                                 @"20110126" :  @"(수) 박새별의 OMG with 박새별",
                                 @"20110127" :  @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20110128" :  @"(금) UV와 공개방송 with UV(유브이)VS 승리",
                                 @"20110128" :  @"(금) [보이는 라디오]  UV와 공개방송 with UV(유브이)VS 승리",
                                 @"20110128" :  @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 승리",
                                 @"20110128" :  @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 승리",
                                 @"20110129" :  @"(토) DJ 그까이꺼",
                                 @"20110130" :  @"(일) 명사와의 만남 with 까치 님",
                                 @"20110131" :  @"(월) 옹달샘과 미정이",
                                 @"20110201" :  @"(화) 사람과 홍보 with 류찬 & 김준호,뮤지의 최신가요 With 뮤지",
                                 @"20110202" :  @"(수) 'OMG, 오 마이 구정' with 박새별",
                                 @"20110203" : @"(목) 설특집 - 그들이 온다 with 옥상달빛 윤주 & 세진,동방신기",
                                 @"20110204" : @"(금) 설특집 - 생방송 교통중심 with 베베미뇽 & 박상민",
                                 @"20110205" : @"(토) DJ 그까이꺼,이무송 노사연 with 김영준",
                                 @"20110206" : @"(일) 명사와의 만남 with 호랑이 님",
                                 @"20110207" : @"(월) 옹달샘과 미정이1",
                                 @"20110207" : @"(월) 옹달샘과 미정이2",
                                 @"20110208" : @"(화) 뮤지의 최신가요 With 뮤지",
                                 @"20110209" : @"(수) 박새별의 OMG with 박새별1",
                                 @"20110209" : @"(수) 박새별의 OMG with 박새별2",
                                 @"20110210" : @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20110210" : @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진1",
                                 @"20110210" : @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진2",
                                 @"20110211" : @"(금) UV와 공개방송 with UV(유브이)VS 보니&인피니트1",
                                 @"20110211" : @"(금) UV와 공개방송 with UV(유브이)VS 보니&인피니트2.mp3",
                                 @"20110211" : @"(금) [보이는 라디오] UV와 공개방송 with UV(유브이)VS 보니&인피니트",
                                 @"20110211" : @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 보니&인피니트",
                                 @"20110211" : @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 보니&인피니트",
                                 @"20110212" : @"(토) DJ 그까이꺼,이무송 노사연 with 김영준",
                                 @"20110213" : @"(일) 명사와의 만남 with 왕자 님",
                                 @"20110214" : @"(월) 옹달샘과 미정이",
                                 @"20110215" : @"(화) 뮤지의 최신가요 With 뮤지1",
                                 @"20110215" : @"(화) 뮤지의 최신가요 With 뮤지2",
                                 @"20110216" : @"(수) 박새별의 OMG with 박새별",
                                 @"20110217" : @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20110218" : @"(금) UV와 공개방송 with UV(유브이)VS 홍경민 & 이정",
                                 @"20110218" : @"(금) [보이는 라디오] UV와 공개방송 with UV(유브이)VS 홍경민,이정",
                                 @"20110218" : @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 홍경민,이정",
                                 @"20110218" : @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 홍경민,이정",
                                 @"20110218" : @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 홍경민,이정",
                                 @"20110219" : @"(금) [VOD] UV와 공개방송 with UV(유브이)VS M4",
                                 @"20110219" : @"(금) [VOD] UV와 공개방송 with UV(유브이)VS M4",
                                 @"20110219" : @"(토) DJ 그까이꺼,이무송 노사연 with 김같이",
                                 @"20110220" : @"(일) 명사와의 만남 with 껌 님",
                                 @"20110221" : @"(월) 옹달샘과 미정이 with 조문근 & 김보경",
                                 @"20110222" : @"(화) 뮤지의 최신가요 With 뮤지",
                                 @"20110223" : @"(수) 박새별의 OMG with 박새별",
                                 @"20110224" : @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20110225" : @"(금) (VOD) UV와 공개방송 with UV(유브이)VS (쥬얼리)주연, (시크릿)징거, (인니피트)동우, (틴탑)C.A.P",
                                 @"20110225" : @"(금) (VOD) UV와 공개방송 with UV(유브이)VS (쥬얼리)주연, (시크릿)징거, (인니피트)동우, (틴탑)C.A.P",
                                 @"20110225" : @"(금) UV와 공개방송 with UV(유브이)VS 나는 래퍼다 with (쥬얼리) 하주연,(시크릿)징거,(인피니트)동우,(틴탑) C.A.P 1",
                                 @"20110225" : @"(금) UV와 공개방송 with UV(유브이)VS 나는 래퍼다 with (쥬얼리) 하주연,(시크릿)징거,(인피니트)동우,(틴탑) C.A.P 2",
                                 @"20110225" : @"(금) [보이는 라디오] UV와 공개방송 with UV(유브이)VS (쥬얼리)주연, (시크릿)징거, (인니피트)동우, (틴탑)C.A.P",
                                 @"20110226" : @"(토) DJ 그까이꺼,이무송 노사연 with 김같이",
                                 @"20110227" : @"(일) 명사와의 만남 with 라면 님",
                                 @"20110228" : @"(월) 옹달샘과 미정이",
                                 @"20110301" : @"(화) 뮤지의 최신가요 With 뮤지",
                                 @"20110302" : @"(수) 박새별의 OMG with 박새별",
                                 @"20110303" : @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20110304" : @"(금) UV와 공개방송 with UV(유브이)VS 아이유(아이유컷)",
                                 @"20110304" : @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 아이유",
                                 @"20110304" : @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 아이유",
                                 @"20110304" : @"(금) UV와 공개방송 with UV(유브이)VS 아이유",
                                 @"20110304" : @"(금) [보이는 라디오] UV와 공개방송 with UV(유브이)VS 아이유(뒤에조금짤림)",
                                 @"20110305" : @"(토) DJ 그까이꺼,이무송 노사연 with 김같이",
                                 @"20110306" : @"(일) 명사와의 만남 with 개구리 님1",
                                 @"20110306" : @"(일) 명사와의 만남 with 개구리 님2",
                                 @"20110307" : @"(월) 옹달샘과 미정이 with 이적",
                                 @"20110308" : @"(화) 박새별의 OMG with 박새별",
                                 @"20110309" : @"(수) 뮤지의 최신가요 With 뮤지",
                                 @"20110310" : @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20110311" : @"(금) 봄특집 - 개콘동창회 with 안상태 & 안영미 & 홍경준 & 홍인규 & 최정화 & 김대범 & 허경환",
                                 @"20110311" : @"(금) [보이는 라디오] 봄특집 - 개콘동창회 with 안상태 & 안영미 & 홍경준 & 홍인규 & 최정화 & 김대범 & 허경환",
                                 @"20110312" : @"(금) [VOD] 봄특집 - 개콘동창회 with 안상태 & 안영미 & 홍경준 & 홍인규 & 최정화 & 김대범 & 허경환",
                                 @"20110312" : @"(금) [VOD] 봄특집 - 개콘동창회 with 안상태 & 안영미 & 홍경준 & 홍인규 & 최정화 & 김대범 & 허경환",
                                 @"20110312" : @"(금) [VOD] 봄특집 - 개콘동창회 with 안상태 & 안영미 & 홍경준 & 홍인규 & 최정화 & 김대범 & 허경환",
                                 @"20110312" : @"(토) DJ 그까이꺼,이무송 노사연 with 김같이",
                                 @"20110313" : @"(일) 명사와의 만남 with 나띵베러양반 님",
                                 @"20110314" : @"(월) 옹달샘과 미정이",
                                 @"20110315" : @"(화) 뮤지의 최신가요 With 뮤지",
                                 @"20110316" : @"(수) 박새별의 OMG with 박새별",
                                 @"20110317" : @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20110318" : @"(금) UV와 공개방송 with UV(유브이)VS M4",
                                 @"20110318" : @"(금) [보이는 라디오] UV와 공개방송 with UV(유브이)VS M4",
                                 @"20110319" : @"(토) DJ 그까이꺼,이무송 노사연 with 김같이",
                                 @"20110320" : @"(일) 명사와의 만남 with 10원 님",
                                 @"20110321" : @"(월) 옹달샘과 미정이",
                                 @"20110322" : @"(화) 뮤지의 최신가요 With 뮤지",
                                 @"20110323" : @"(수) 박새별의 OMG with 박새별",
                                 @"20110324" : @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20110325" : @"(금) UV와 공개방송 with UV(유브이)VS 김형준 & 레이디제인",
                                 @"20110325" : @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 김형준 & 레이디제인",
                                 @"20110325" : @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 김형준 & 레이디제인",
                                 @"20110326" : @"(토) DJ 그까이꺼,이무송 노사연 with 김같이",
                                 @"20110327" : @"(일) 명사와의 만남 with 터미네이터 님",
                                 @"20110328" : @"(월) 옹달샘과 미정이",
                                 @"20110329" : @"(화) 뮤지의 최신가요 With 뮤지1",
                                 @"20110329" : @"(화) 뮤지의 최신가요 With 뮤지2",
                                 @"20110330" : @"(수) 박새별의 OMG with 박새별",
                                 @"20110331" : @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20110401" : @"(금) UV와 공개방송 with UV(유브이)VS 간미연 & 나윤권",
                                 @"20110401" : @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 나윤권,간미연",
                                 @"20110401" : @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 나윤권,간미연",
                                 @"20110402" : @"(토) DJ 그까이꺼,추억을 파는 가게 with 김같이",
                                 @"20110403" : @"(일) 명사와의 만남 with 뼈그맨 님",
                                 @"20110404" : @"(월) 옹달샘과 미정이1",
                                 @"20110404" : @"(월) 옹달샘과 미정이2",
                                 @"20110405" : @"(화) 뮤지의 최신가요 With 뮤지",
                                 @"20110406" : @"(수) 박새별의 OMG with 박새별",
                                 @"20110407" : @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20110408" : @"(금) UV와 공개방송 with UV(유브이)",
                                 @"20110408" : @"(금) [보이는 라디오] UV와 공개방송 with UV(유브이)",
                                 @"20110408" : @"(금) [VOD] UV와 공개방송 with UV(유브이)",
                                 @"20110408" : @"(금) [VOD] UV와 공개방송 with UV(유브이)",
                                 @"20110409" : @"(토) DJ 그까이꺼,추억을 파는 가게 with 김같이",
                                 @"20110410" : @"(일) 명사와의 만남 with 아이돌 님",
                                 @"20110411" : @"(월) 옹달샘과 미정이",
                                 @"20110412" : @"(화) 뮤지의 최신가요 With 뮤지",
                                 @"20110413" : @"(수) 박새별의 OMG with 박새별",
                                 @"20110414" : @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20110415" : @"(금) UV와 공개방송 with UV(유브이)VS 브라이언",
                                 @"20110415" : @"(금) [보이는 라디오] UV와 공개방송 with UV(유브이)VS 브라이언",
                                 @"20110415" : @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 브라이언",
                                 @"20110415" : @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 브라이언",
                                 @"20110416" : @"(토) DJ 그까이꺼,추억을 파는 가게 with 김같이",
                                 @"20110417" : @"(일) 명사와의 만남 with 둘리 님",
                                 @"20110418" : @"(월) 옹달샘과 미정이",
                                 @"20110419" : @"(화) 뮤지의 최신가요 With 뮤지",
                                 @"20110420" : @"(수) 박새별의 OMG with 박새별",
                                 @"20110421" : @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20110422" : @"(금) UV와 공개방송 with UV(유브이)VS 노브레인",
                                 @"20110422" : @"(금) UV와 공개방송 with UV(유브이)VS 노브레인_Repair",
                                 @"20110422" : @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 노브레인",
                                 @"20110422" : @"(금) [VOD] UV와 공개방송 with UV(유브이)VS 노브레인",
                                 @"20110423" : @"(토) DJ 그까이꺼,추억을 파는 가게 with 김같이",
                                 @"20110424" : @"(일) 명사와의 만남 with 말년병장 님",
                                 @"20110425" : @"(월) 옹달샘과 미정이",
                                 @"20110426" : @"(화) 뮤지의 최신가요 With 뮤지",
                                 @"20110427" : @"(수) 박새별의 OMG with 박새별1",
                                 @"20110427" : @"(수) 박새별의 OMG with 박새별2",
                                 @"20110428" : @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20110429" : @"(금) UV와 공개방송 with UV(유브이)VS 씨엔블루",
                                 @"20110429" : @"(금) UV와 공개방송 with UV(유브이)VS 씨엔블루",
                                 @"20110429" : @"(금) UV와 공개방송 with UV(유브이)VS 씨엔블루",
                                 @"20110429" : @"(금) [보이는 라디오] UV와 공개방송 with UV(유브이)VS 씨엔블루",
                                 @"20110430" : @"(토) DJ 그까이꺼,추억을 파는 가게 with 김같이",
                                 @"20110501" : @"(일) 명사와의 만남 with 매니저 님",
                                 @"20110502" : @"(월) 옹달샘과 미정이",
                                 @"20110504" : @"(수) 박새별의 OMG with 박새별",
                                 @"20110505" : @"(목) 옥달의 롤링페이퍼 with 옥상달빛 윤주 & 세진",
                                 @"20110506" : @"(금) 안녕, 옹꾸라 with 김같이&박새별&뮤지&옥상달빛",
                                 @"20110506" : @"(금) [보이는 라디오] 안녕, 옹꾸라 with 김같이&박새별&뮤지&옥상달빛",
                                 @"20110506" : @"(금) [VOD] 안녕, 옹꾸라 with 김같이&박새별&뮤지&옥상달빛",
                                 @"20110506" : @"(금) [VOD] 안녕, 옹꾸라 with 김같이&박새별&뮤지&옥상달빛",
                                 @"20110506" : @"(금) [VOD] 안녕, 옹꾸라 with 김같이&박새별&뮤지&옥상달빛",
                                 @"20110507" : @"(토) DJ 그까이꺼,추억을 파는 가게 with 김같이",
                                 @"20110508" : @"(일) 마지막방송"
                                 };
    return dataSource[key];
}

@end
