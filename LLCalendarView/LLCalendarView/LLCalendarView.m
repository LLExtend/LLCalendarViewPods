//
//  LLCalendarView.m
//  LLCalendarView
//
//  Created by Mac on 2019/7/31.
//  Copyright © 2019 zyl. All rights reserved.
//

#import "LLCalendarView.h"
#import "LLCalendarDateHandle.h"
#import "LLCalendarModel.h"

#define kLayoutScale(layout) ((layout)*(UIScreen.mainScreen.bounds.size.width/375.0f))

@interface LLCalendarMonthCollectionViewLayout : UICollectionViewFlowLayout

@end

@implementation LLCalendarMonthCollectionViewLayout

- (void)prepareLayout {
    [super prepareLayout];
    
    CGFloat collectViewWidth = self.collectionView.frame.size.width;
    
    CGFloat minimumInteritemSpacing = 0.f;
    CGFloat leftInset = 4.f;
    CGFloat rightInset = 4.f;
    
    CGFloat layoutWidth = (collectViewWidth - minimumInteritemSpacing * 6 - leftInset - rightInset);
    
    CGFloat itemWidth = floor((layoutWidth / 7));
    CGFloat itemHeight = itemWidth * 1.2;
    
    // 用来计算 layoutWidth / 7 无法除尽 造成误差问题
    NSInteger collectionViewLayoutWidth = (int)itemWidth * 7;
    // 计算得出误差 均分到leftInset、rightInset
    CGFloat margin = (layoutWidth - collectionViewLayoutWidth) / 2;
    leftInset += margin;
    rightInset += margin;
    
    self.headerReferenceSize = CGSizeMake(collectViewWidth, 40);
    self.itemSize = CGSizeMake(itemWidth, itemHeight);
    self.minimumLineSpacing = 4.0f;
    self.minimumInteritemSpacing = minimumInteritemSpacing;
    self.sectionInset = UIEdgeInsetsMake(0, leftInset, 4, rightInset);
}

- (void)dealloc {
    NSLog(@"%s", __func__);
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {

    //UICollectionViewLayoutAttributes：可理解为collectionView中的item（包括cell和header、footer这些）的《结构信息》
    //截取到父类所返回的数组（里面放的是当前屏幕所能展示的item的结构信息）
    NSMutableArray *collectionViewLayoutAttributes = [[super layoutAttributesForElementsInRect:rect] mutableCopy];

    //创建存索引的数组，无符号（正整数），无序（不能通过下标取值），不可重复（重复的话会自动过滤）
    NSMutableIndexSet *missingSections = [NSMutableIndexSet indexSet];

    //遍历collectionViewLayoutAttributes，得到一个当前屏幕中所有的section数组
    for (UICollectionViewLayoutAttributes *layoutAttributes in collectionViewLayoutAttributes) {
        if (layoutAttributes.representedElementCategory == UICollectionElementCategoryCell) {
            [missingSections addIndex:layoutAttributes.indexPath.section];
        }
    }

    //遍历collectionViewLayoutAttributes，将当前屏幕中拥有的header的section从数组中移除，得到一个当前屏幕中没有header的section数组
    //正常情况下，随着手指往上移，header脱离屏幕会被系统回收而cell尚在，也会触发该方法
    for (UICollectionViewLayoutAttributes *layoutAttributes in collectionViewLayoutAttributes) {
        //如果当前的元素是一个header，将header所在的section从数组中移除
        if ([layoutAttributes.representedElementKind isEqualToString:UICollectionElementKindSectionHeader]) {
            [missingSections removeIndex:layoutAttributes.indexPath.section];
        }
    }

    //遍历当前屏幕中没有header的section数组
    [missingSections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        //取到当前section中第一个item的indexPath
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:idx];
        //获取当前section在正常情况下已经离开屏幕的header结构信息
        UICollectionViewLayoutAttributes *layoutAttributes = [self layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader atIndexPath:indexPath];
        //如果当前分区确实有因为离开屏幕而被系统回收的header
        if (layoutAttributes) {
            //将该header结构信息重新加入到collectionViewLayoutAttributes中去
            [collectionViewLayoutAttributes addObject:layoutAttributes];
        }
    }];

    //遍历collectionViewLayoutAttributes，改变header结构信息中的参数，使它可以在当前section还没完全离开屏幕的时候一直显示
    for (UICollectionViewLayoutAttributes *layoutAttributes in collectionViewLayoutAttributes) {
        //如果当前item是header
        if ([layoutAttributes.representedElementKind isEqualToString:UICollectionElementKindSectionHeader]) {
            //得到当前header所在分区的cell的数量
            NSInteger section = layoutAttributes.indexPath.section;
            NSInteger numberOfItemsInSection = [self.collectionView numberOfItemsInSection:section];

            NSIndexPath *firstObjectIndexPath = [NSIndexPath indexPathForItem:0 inSection:section];
            NSIndexPath *lastObjectIndexPath = [NSIndexPath indexPathForItem:MAX(0, (numberOfItemsInSection - 1)) inSection:section];

            UICollectionViewLayoutAttributes *firstObjectAttrs;
            UICollectionViewLayoutAttributes *lastObjectAttrs;

            if (numberOfItemsInSection > 0) {
                firstObjectAttrs = [self layoutAttributesForItemAtIndexPath:firstObjectIndexPath];
                lastObjectAttrs = [self layoutAttributesForItemAtIndexPath:lastObjectIndexPath];
            } else {
                firstObjectAttrs = [self layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                                                        atIndexPath:firstObjectIndexPath];
                lastObjectAttrs = [self layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                                                                       atIndexPath:lastObjectIndexPath];
            }

            CGFloat headerHeight = CGRectGetHeight(layoutAttributes.frame);
            CGPoint origin = layoutAttributes.frame.origin;
            CGFloat tempContentOffset = MAX((self.collectionView.contentOffset.y + self.collectionView.contentInset.top), (CGRectGetMinY(firstObjectAttrs.frame) - headerHeight));
            origin.y = MIN(
                           tempContentOffset,
                           (CGRectGetMaxY(lastObjectAttrs.frame) - headerHeight)
                           );

            layoutAttributes.zIndex = NSIntegerMax;
            layoutAttributes.frame = (CGRect) {
                .origin = origin,
                .size = layoutAttributes.frame.size
            };
        }
    }
    return [collectionViewLayoutAttributes copy];
}

//表示一旦滑动就实时调用上面这个layoutAttributesForElementsInRect:方法
- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBound {
    return YES;
}

@end


@interface LLCalendarMonthCollectionSectionHeader : UICollectionReusableView

- (void)setConfiguration:(LLCalendarViewConfiguration *)configuration
                dayModel:(LLCalendarMonthModel *)monthModel;

@end

@implementation LLCalendarMonthCollectionSectionHeader {
    UILabel *_titleLabel;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _titleLabel = [[UILabel alloc] init];
        [_titleLabel setFont:[UIFont systemFontOfSize:18]];
        [_titleLabel setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
        [_titleLabel setTextAlignment:NSTextAlignmentCenter];
        [self addSubview:_titleLabel];
        [_titleLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    }
    return self;
}

- (void)setConfiguration:(LLCalendarViewConfiguration *)configuration
                dayModel:(LLCalendarMonthModel *)monthModel {
    _titleLabel.textColor = configuration.sectionHeaderConfiguration.sectionHeaderTextColor ?:[UIColor blackColor];
    _titleLabel.backgroundColor = configuration.sectionHeaderConfiguration.sectionHeaderBackgroundColor ?:[UIColor groupTableViewBackgroundColor];
    _titleLabel.font = configuration.sectionHeaderConfiguration.sectionHeaderTextFont ?:[UIFont systemFontOfSize:18];
    _titleLabel.text = [NSString stringWithFormat:@"%d年 %d月",(int)monthModel.year,(int)monthModel.month];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    _titleLabel.frame = self.bounds;
}

@end

@interface LLCalendarCollectionCell : UICollectionViewCell

- (void)setConfiguration:(LLCalendarViewConfiguration *)configuration
                dayModel:(LLCalendarDayModel *)dayModel;

@end

@implementation LLCalendarCollectionCell {
    UIView *_contentBackgroundView;
    UILabel *_holidayLabel;
    UILabel *_titleLabel;
    UILabel *_markLabel;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        
        _contentBackgroundView = UIView.new;
        [self.contentView addSubview:_contentBackgroundView];
        
        _holidayLabel = UILabel.new;
        [_contentBackgroundView addSubview:_holidayLabel];
        
        _titleLabel = [[UILabel alloc] init];
        [_contentBackgroundView addSubview:_titleLabel];
        
        _markLabel = UILabel.new;
        [_contentBackgroundView addSubview:_markLabel];
        
        _holidayLabel.font = [UIFont systemFontOfSize:10];
        _holidayLabel.textColor = [UIColor colorWithRed:255/255.0 green:110/255.0 blue:0/255.0 alpha:1];
        _holidayLabel.textAlignment = NSTextAlignmentCenter;
        
        _titleLabel.font = [UIFont boldSystemFontOfSize:16];
        _titleLabel.textColor = [UIColor colorWithRed:51/255.0 green:51/255.0 blue:51/255.0 alpha:1];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        
        _markLabel.font = [UIFont systemFontOfSize:10];
        _markLabel.textColor = [UIColor whiteColor];
        _markLabel.textAlignment = NSTextAlignmentCenter;
        _markLabel.hidden = YES;
    
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    NSMutableDictionary *attr = [NSMutableDictionary new];
    attr[NSFontAttributeName] = _holidayLabel.font;
    
    CGRect rect = [@"" boundingRectWithSize:CGSizeMake(CGRectGetWidth(_contentBackgroundView.frame), HUGE)
                                     options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                  attributes:attr context:nil];
   
    CGFloat height = rect.size.height;
    
    CGFloat scale = .4;
    CGFloat titleHeight = CGRectGetHeight(self.frame) * scale;
    CGFloat holidayHeight = CGRectGetHeight(self.frame) * ((1 - scale) / 2);
    _contentBackgroundView.frame = self.bounds;
    _holidayLabel.frame = CGRectMake(0, holidayHeight - height, CGRectGetWidth(_contentBackgroundView.frame), height);
    _titleLabel.frame = CGRectMake(0, CGRectGetMaxY(_holidayLabel.frame), CGRectGetWidth(_contentBackgroundView.frame), titleHeight);
    _markLabel.frame = CGRectMake(0, CGRectGetMaxY(_titleLabel.frame), CGRectGetWidth(_contentBackgroundView.frame), height);
}

- (void)setConfiguration:(LLCalendarViewConfiguration *)configuration
                dayModel:(LLCalendarDayModel *)dayModel {
   
    _titleLabel.textColor = configuration.weeknormalTextColor ?:[UIColor colorWithRed:51/255.0 green:51/255.0 blue:51/255.0 alpha:1];
    
    _titleLabel.text = [NSString stringWithFormat:@"%ld",(long)dayModel.day];
    
    _titleLabel.font = configuration.weekDayTextFont ?:[UIFont boldSystemFontOfSize:16];
    
    LLCalendarDayOfWeek dayOfWeek = dayModel.dayOfWeek;
    switch (dayOfWeek) {
        case LLCalendarDayOfWeekSunday:
            _titleLabel.textColor = configuration.weekendTextColor ?:UIColor.orangeColor;
            _titleLabel.font = configuration.weekendTextFont ?:[UIFont boldSystemFontOfSize:16];
            break;
        case LLCalendarDayOfWeekSaturday:
            _titleLabel.textColor = configuration.weekendTextColor ?:UIColor.orangeColor;
            _titleLabel.font = configuration.weekendTextFont ?:[UIFont boldSystemFontOfSize:16];
            break;
        case LLCalendarDayOfWeekUnknown:
            _titleLabel.text = @"";
            break;
        case LLCalendarDayOfWeekMonday:
            
            break;
        case LLCalendarDayOfWeekTuesday:
            
            break;
        case LLCalendarDayOfWeekWednesday:
            
            break;
        case LLCalendarDayOfWeekThursday:
            
            break;
        case LLCalendarDayOfWeekFriday:
            
            break;
    }
    
    [self setCornerRadius:0 masksToBounds:NO];
    
    _holidayLabel.textColor = [UIColor colorWithRed:255/255.0 green:110/255.0 blue:0/255.0 alpha:1];
    _markLabel.hidden = YES;
    
    switch (dayModel.dayState) {
        case LLCalendarDayStateUnable:
            _titleLabel.text = @"";
            _contentBackgroundView.backgroundColor = UIColor.whiteColor;
            break;
        case LLCalendarDayStateUntouch:
            _contentBackgroundView.backgroundColor = UIColor.whiteColor;
            _titleLabel.textColor = configuration.untouchTextColor ?:UIColor.lightGrayColor;
            _holidayLabel.textColor = configuration.untouchTextColor ?:UIColor.lightGrayColor;
            break;
        case LLCalendarDayStateNormal:
            _contentBackgroundView.backgroundColor = UIColor.whiteColor;
            break;
        case LLCalendarDayStateSelectStart:
            _contentBackgroundView.backgroundColor = configuration.selectedBackgroundColor ?:UIColor.blueColor;
            _titleLabel.textColor = UIColor.whiteColor;
            _holidayLabel.textColor = UIColor.whiteColor;
            _markLabel.hidden = NO;
            _markLabel.text = configuration.startMarkString;
            [self setCornerRadius:3 masksToBounds:YES];
            break;
        case LLCalendarDayStateSelectEnd:
            _contentBackgroundView.backgroundColor = configuration.selectedBackgroundColor ?:UIColor.blueColor;
            _titleLabel.textColor = UIColor.whiteColor;
            _holidayLabel.textColor = UIColor.whiteColor;
            _markLabel.hidden = NO;
            _markLabel.text = configuration.endMarkString;
            [self setCornerRadius:3 masksToBounds:YES];
            break;
        case LLCalendarDayStateSelect:
            _contentBackgroundView.backgroundColor = configuration.selectedMiddleBackgroundColor ?:UIColor.cyanColor;
            break;
    }
}

- (void)setCornerRadius:(CGFloat)cornerRadius masksToBounds:(BOOL)masksToBounds {
    _contentBackgroundView.layer.cornerRadius = cornerRadius;
    _contentBackgroundView.layer.masksToBounds = masksToBounds;
}

@end

static NSString const *startIndexPathKey = @"startIndexPathKey";
static NSString const *endIndexPathKey = @"endIndexPathKey";


typedef struct {
    NSDate *startDate;
    NSDate *endDate;
} LLCalendarDateAllowSelectRange;

@interface LLCalendarView () <UICollectionViewDelegate ,UICollectionViewDataSource>
@property (nonatomic ,strong) UIView *weekDayView;
@property (nonatomic ,strong) UICollectionView *collectionView;
@property (nonatomic ,strong) NSMutableArray *dataArray;

@property (nonatomic ,strong ,readwrite) NSArray <LLCalendarDayModel *> *selectedDates;
@end

@implementation LLCalendarView {
    BOOL _isAlreadyExistStart;
    BOOL _isAlreadyExistEnd;
    NSMutableDictionary *_recordIndexPaths;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self initSubViews];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.weekDayView.frame = CGRectMake(0, 0, self.frame.size.width, kLayoutScale(35));
    self.collectionView.frame = CGRectMake(0, CGRectGetMaxY(self.weekDayView.frame), self.frame.size.width, CGRectGetHeight(self.frame) - CGRectGetMaxY(self.weekDayView.frame));
}

- (void)initSubViews {
    
    _recordIndexPaths = NSMutableDictionary.dictionary;
    
    [self addSubview:self.weekDayView];
    
    [self addSubview:self.collectionView];
    
    //初始化后快速滑动闪退
    //解决bug Assertion failure in -[UICollectionViewData validateLayoutInRect:]
    if (@available(iOS 10.0, *)) {
        if ([self.collectionView respondsToSelector:@selector(setPrefetchingEnabled:)]) {
            self.collectionView.prefetchingEnabled = NO;
        }
    }
}

#pragma mark - UICollectionView Delegate & DataSource
//定义展示的Section的个数
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return self.dataArray.count;
}

//定义展示的UICollectionViewCell的个数
- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    return [self.dataArray[section] dayModels].count;
}

//每个UICollectionView展示的内容
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    LLCalendarCollectionCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"LLCalendarCollectionCell" forIndexPath:indexPath];
    LLCalendarDayModel *dayModel = [self dayModelForIndexPath:indexPath];
    [cell setConfiguration:self.configuration dayModel:dayModel];
    if (dayModel.dayState == LLCalendarDayStateSelectStart) {
        _recordIndexPaths[startIndexPathKey] = indexPath;
    } else if (dayModel.dayState == LLCalendarDayStateSelectEnd) {
        _recordIndexPaths[endIndexPathKey] = indexPath;
    }
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath {
    UICollectionReusableView *reusableview = nil;
    if (kind == UICollectionElementKindSectionHeader) {
        LLCalendarMonthModel *monthModel = self.dataArray[indexPath.section];
        LLCalendarMonthCollectionSectionHeader *monthHeader = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"LLCalendarMonthCollectionSectionHeader" forIndexPath:indexPath];
        [monthHeader setConfiguration:self.configuration dayModel:monthModel];
        monthHeader.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8f];
        reusableview = monthHeader;
    }
    return reusableview;
}

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath {

    LLCalendarDayModel *dayModel = [self dayModelForIndexPath:indexPath];
    if (dayModel.dayState == LLCalendarDayStateUnable ||
        dayModel.dayState == LLCalendarDayStateUntouch) {
        return;
    }
    
    // 开启单选
    if (_configuration.isOpenSingleSelect) {
        [self singleSelectProcessor:indexPath];
    } else {
        // 双选
        [self twiceSelectProcessor:indexPath];
    }
}

- (void)setConfiguration:(LLCalendarViewConfiguration *)configuration {
//    LLCalendarDateFillConfiguration fill;
//    fill.startDate = [LLCalendarDateHandle dateWithYear:2019 month:9 day:12];
//    fill.endDate = [LLCalendarDateHandle dateWithYear:2020 month:3 day:1];
//    configuration.dateFillConfiguration = fill;
//    configuration.fillRangeType = LLCalendarFillRangeTypeAnyDateOutInvalid;
    
    _configuration = configuration;
    

    [self dataSourceProcessor];
    
    [self weekDayViewSubViewPropertySetting];
}

#pragma mark - private method
// 日期处理
- (void)dataSourceProcessor {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        // 得到当前时间（世界标准时间 UTC/GMT）
        // [LLCalendarDateHandle currentDate];
        NSDate *nowDate = NSDate.date;
        
        // 日历
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSUInteger unitFlags = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitWeekday;
        NSDateComponents *components = [calendar components:unitFlags fromDate:nowDate];
        
        // 获取当前月份
        NSInteger month = components.month;
        
        NSDate *startDate = [LLCalendarDateHandle dateWithYear:components.year month:components.month day:components.day];
        
        NSInteger addMonthCount = 0;
        NSDate *endDate = nil;
        
        BOOL isAllowFill = [self isAllowFill:startDate components:components];
        
        if (strongSelf.configuration.calculateRangeCountType == LLCalendarCalculateRangeCountTypeMonth) {
            // 按月计算
            addMonthCount = strongSelf.configuration.calculateRangeCount-1;
        } else {
            // 按天计算
            NSTimeInterval timeInterval = 3600 * 24 * (strongSelf.configuration.calculateRangeCount - 1) ;
            endDate = [startDate dateByAddingTimeInterval:timeInterval];
            NSDateComponents *endComponents = [calendar components:unitFlags fromDate:endDate];
            NSInteger startYear = components.year;
            NSInteger endYear = endComponents.year;
            NSInteger endMonth = endComponents.month;
            
            if (startYear == endYear) {
                // 年份相同时 相差月数
                addMonthCount = (endMonth - month);
            } else {
                // 年份不同时 获取相差月数
                addMonthCount = (12 - month + (endYear - startYear - 1) * 12 + endMonth);
            }
        }
        
        NSInteger year = components.year;
        NSInteger index = month;
        
        NSMutableArray *months = NSMutableArray.array;
        for (NSInteger i = month; i <= month + addMonthCount; i++) {
            
            // 计算月
            if (i % 12 == 0) {
                index = 12;
            } else {
                index = i % 12;
            }
            
            LLCalendarMonthModel *monthModel = LLCalendarMonthModel.new;
            monthModel.year = year;
            monthModel.month = index;
            
            NSDate *last = [LLCalendarDateHandle dateWithYear:year month:index day:1];
            NSInteger days = [LLCalendarDateHandle totaldaysInMonth:last];
            NSInteger lastWeekDay = [LLCalendarDateHandle weekDayForDate:last];
            NSMutableArray *dayModels = NSMutableArray.array;
            
            // 补全一号之前空白数据
            for (NSInteger ii = 0; ii < lastWeekDay; ii++) {
                LLCalendarDayModel *dayModel = LLCalendarDayModel.new;
                dayModel.dayOfWeek = LLCalendarDayOfWeekUnknown;
                dayModel.dayState = LLCalendarDayStateUnable;
                [dayModels addObject:dayModel];
            }
            
            // 初始化每一天时间模型
            for (NSInteger j = 1; j <= days; j++) {
                NSDate *date = [LLCalendarDateHandle dateWithYear:year month:index day:j];
                NSInteger compareStartResult = [LLCalendarDateHandle compareOriginDate:startDate compareDate:date];
                NSInteger compareEndResult ;
                LLCalendarDayState dayState ;
                if (self.configuration.calculateRangeCountType == LLCalendarCalculateRangeCountTypeDay) {
                    compareEndResult = [LLCalendarDateHandle compareOriginDate:endDate compareDate:date];
                    if (compareEndResult == 1 ||
                        compareStartResult == -1) {
                        dayState = LLCalendarDayStateUntouch;
                    } else {
                        dayState = LLCalendarDayStateNormal;
                    }
                } else {
                    dayState = (compareStartResult == -1 ? LLCalendarDayStateUntouch : LLCalendarDayStateNormal);
                }
                
                // 回显数据处理
                if (isAllowFill) {
                    dayState = [strongSelf fillProcessor:date dayState:dayState];
                    /*
                     🌟
                     indexPath
                     section == months.count
                     row == dayModels.count
                     🌟
                     */
                }
                
                LLCalendarDayModel *dayModel = LLCalendarDayModel.new;
                dayModel.year = monthModel.year;
                dayModel.month = monthModel.month;
                dayModel.day = j;
                dayModel.date = date;
                dayModel.dayOfWeek = [LLCalendarDateHandle weekDayForDate:date];
                dayModel.dayState = dayState;
                [dayModels addObject:dayModel];
            }
            monthModel.totalDays = days;
            monthModel.dayModels = dayModels;
            [months addObject:monthModel];
            
            // 计算年 遇到12月份时 年份+1
            if (i / 12 &&
                i % 12 == 0) {
                year = components.year + i / 12;
            }
        }
        
        [strongSelf.dataArray removeAllObjects];
        [strongSelf.dataArray addObjectsFromArray:months];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf.collectionView reloadData];
//            [strongSelf.collectionView.collectionViewLayout invalidateLayout];
        });
    });
}

// 是否允许回显日期范围
- (BOOL)isAllowFill:(NSDate *)today components:(NSDateComponents *)components {
    NSDate *startDate = _configuration.dateFillConfiguration.startDate;
    NSInteger compareStartResult = [LLCalendarDateHandle compareOriginDate:today compareDate:startDate];
    if (compareStartResult == -1) {
        if (_configuration.fillRangeType == LLCalendarFillRangeTypeAnyDateOutFillBase) {
            _configuration.dateFillConfiguration = LLCalendarDateFillConfigurationMake(today, _configuration.dateFillConfiguration.endDate);
        } else {
            return NO;
        }
    }
    
    NSDate *fillEndDate = _configuration.dateFillConfiguration.endDate;
    if (_configuration.calculateRangeCountType == LLCalendarCalculateRangeCountTypeDay) {
        NSTimeInterval timeInterval = 3600 * 24 * (_configuration.calculateRangeCount - 1) ;
        NSDate *endDate = [today dateByAddingTimeInterval:timeInterval];
        NSInteger compareEndResult = [LLCalendarDateHandle compareOriginDate:fillEndDate compareDate:endDate];
        if (compareEndResult == -1) {
            if (_configuration.fillRangeType == LLCalendarFillRangeTypeAnyDateOutFillBase) {
                _configuration.dateFillConfiguration = LLCalendarDateFillConfigurationMake(_configuration.dateFillConfiguration.startDate, endDate);
            } else {
                return NO;
            }
        }
    } else {
        NSInteger calculateRangeCount = _configuration.calculateRangeCount - 1;
        NSInteger year = components.year;
        NSInteger month = components.month;
        NSInteger addMonth = (month + calculateRangeCount);
        
        NSInteger endMonth = addMonth % 12;
        NSInteger endYear = addMonth / 12;
        endYear += year;
        
        // 获取结束年月 当前月份天数
        NSInteger endDay = [LLCalendarDateHandle totaldaysInMonth:[LLCalendarDateHandle dateWithYear:endYear month:endMonth day:1]];
        
        NSDate *endDate = [LLCalendarDateHandle dateWithYear:endYear month:endMonth day:endDay];
        NSInteger compareEndResult = [LLCalendarDateHandle compareOriginDate:fillEndDate compareDate:endDate];
        if (compareEndResult == -1) {
            if (_configuration.fillRangeType == LLCalendarFillRangeTypeAnyDateOutFillBase) {
                _configuration.dateFillConfiguration = LLCalendarDateFillConfigurationMake(_configuration.dateFillConfiguration.startDate, endDate);
            } else {
                return NO;
            }
        }
    }

    return YES;
}

- (LLCalendarDayState)fillProcessor:(NSDate *)date dayState:(LLCalendarDayState)dayState {
    
    NSDate *startDate = _configuration.dateFillConfiguration.startDate;
    // 单选回显
    if (_configuration.isOpenSingleSelect) {
        if (startDate) {
            NSInteger compareStartResult = [LLCalendarDateHandle compareOriginDate:startDate compareDate:date];
            if (compareStartResult == 0) {
                dayState = LLCalendarDayStateSelectStart;
                _isAlreadyExistStart = YES;
            }
        }
    } else {
        NSDate *endDate = _configuration.dateFillConfiguration.endDate;
        // 双选回显
        if (startDate && endDate) {
            NSInteger compareStartResult = [LLCalendarDateHandle compareOriginDate:startDate compareDate:date];
            NSInteger compareEndResult = [LLCalendarDateHandle compareOriginDate:endDate compareDate:date];
            
        
            if (compareEndResult == -1 &&
                compareStartResult == 1) {
                dayState = LLCalendarDayStateSelect;
            } else if (compareStartResult == 0) {
                dayState = LLCalendarDayStateSelectStart;
                _isAlreadyExistStart = YES;
            } else if (compareEndResult == 0) {
                dayState = LLCalendarDayStateSelectEnd;
                _isAlreadyExistEnd = YES;
            }
        }
    }
    
    return dayState;
}

// 单次选择处理
- (void)singleSelectProcessor:(NSIndexPath *)indexPath {
    LLCalendarDayModel *dayModel = [self dayModelForIndexPath:indexPath];
    if (_isAlreadyExistStart) {
        NSIndexPath *singleIndexPath = _recordIndexPaths[startIndexPathKey];
        if ([singleIndexPath isEqual:indexPath]) {
            return;
        }
        LLCalendarDayModel *singleDayModel = [self dayModelForIndexPath:singleIndexPath];
        singleDayModel.dayState = LLCalendarDayStateNormal;
        _recordIndexPaths[startIndexPathKey] = indexPath;
        dayModel.dayState = LLCalendarDayStateSelectStart;
        [self.collectionView reloadItemsAtIndexPaths:@[singleIndexPath,indexPath]];
        
        self.selectedDates = @[dayModel];
        if (self.finishSelectBlock) {
            self.finishSelectBlock(self.selectedDates);
        }
    } else {
        _isAlreadyExistStart = YES;
        _recordIndexPaths[startIndexPathKey] = indexPath;
        dayModel.dayState = LLCalendarDayStateSelectStart;
        [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
        
        self.selectedDates = @[dayModel];
        if (self.finishSelectBlock) {
            self.finishSelectBlock(self.selectedDates);
        }
    }
}

// 两次选择处理
- (void)twiceSelectProcessor:(NSIndexPath *)indexPath {
    LLCalendarDayModel *dayModel = [self dayModelForIndexPath:indexPath];
    // 选中开始和结束状态
    if (_isAlreadyExistStart && _isAlreadyExistEnd) {
        
        NSIndexPath *startIndexPath = _recordIndexPaths[startIndexPathKey];
        NSIndexPath *endIndexPath = _recordIndexPaths[endIndexPathKey];
        
        // 取消上次选中状态
        for (NSInteger i = startIndexPath.section; i <= endIndexPath.section; i++) {
            LLCalendarMonthModel *indexMonthModel = self.dataArray[i];
            NSInteger dayStartIndex = (startIndexPath.section == i ? startIndexPath.row : 0);
            NSInteger dayEndIndex = ((i > startIndexPath.section && i < endIndexPath.section) ? indexMonthModel.dayModels.count : endIndexPath.row);
            
            if (endIndexPath.section == startIndexPath.section) {
                dayStartIndex = startIndexPath.row;
                dayEndIndex = endIndexPath.row;
            } else  {
                if (i > startIndexPath.section && i < endIndexPath.section) {
                    dayStartIndex = 0;
                    dayEndIndex = indexMonthModel.dayModels.count-1;
                } else if (i == startIndexPath.section && i < endIndexPath.section) {
                    dayStartIndex = startIndexPath.row;
                    dayEndIndex = indexMonthModel.dayModels.count-1;
                } else if (i > startIndexPath.section && i == endIndexPath.section) {
                    dayStartIndex = 0;
                    dayEndIndex = endIndexPath.row;
                }
            }
            
            for (NSInteger j = dayStartIndex; j <= dayEndIndex; j++) {
                LLCalendarDayModel *dd = indexMonthModel.dayModels[j];
                if (dd.dayState == LLCalendarDayStateUnable) {
                    continue;
                }
                dd.dayState = LLCalendarDayStateNormal;
            }
        }
        
        dayModel.dayState = LLCalendarDayStateSelectStart;
        
        _recordIndexPaths[startIndexPathKey] = indexPath;
        [_recordIndexPaths removeObjectForKey:endIndexPathKey];
        
        _isAlreadyExistEnd = NO;
        _isAlreadyExistStart = YES;
        
        [self.collectionView reloadData];
    }
    else if (_isAlreadyExistStart && !_isAlreadyExistEnd) {
        // 选中开始 状态
        NSIndexPath *startIndexPath = _recordIndexPaths[startIndexPathKey];
        LLCalendarDayModel *startDayModel = [self dayModelForIndexPath:startIndexPath];
        
        NSInteger inn = [LLCalendarDateHandle compareOriginDate:startDayModel.date compareDate:dayModel.date];
        if (inn == -1) {
            _isAlreadyExistEnd = NO;
            _isAlreadyExistStart = YES;
            _recordIndexPaths[startIndexPathKey] = indexPath;
            startDayModel.dayState = LLCalendarDayStateNormal;
            dayModel.dayState = LLCalendarDayStateSelectStart;
            [self.collectionView reloadItemsAtIndexPaths:@[indexPath ,startIndexPath]];
            // [collectionView reloadData];
            return;
        }
        
        if (inn == 0) {
            return;
        }
        
        dayModel.dayState = LLCalendarDayStateSelectEnd;
        _isAlreadyExistEnd = YES;
        _isAlreadyExistStart = YES;
        _recordIndexPaths[endIndexPathKey] = indexPath;
        
        // 找出选择开始和结束日期之间的日期
        for (NSInteger i = startIndexPath.section; i <= indexPath.section; i++) {
            LLCalendarMonthModel *startMonthModel = self.dataArray[i];
            for (LLCalendarDayModel *dd in startMonthModel.dayModels) {
                if (dd.dayState == LLCalendarDayStateSelectStart ||
                    dd.dayState == LLCalendarDayStateUnable) {
                    continue;
                }
                
                if (dd.dayState == LLCalendarDayStateSelectEnd) {
                    break;
                }
                
                BOOL isMiddle = [LLCalendarDateHandle compareStartDate:startDayModel.date endDate:dayModel.date compareDate:dd.date];
                
                if (isMiddle) {
                    dd.dayState = LLCalendarDayStateSelect;
                }
            }
        }
        
        [self.collectionView reloadData];
        
        self.selectedDates = @[startDayModel ,dayModel];
        if (self.finishSelectBlock) {
            self.finishSelectBlock(self.selectedDates);
        }
        
    }
    else if (!_isAlreadyExistStart && !_isAlreadyExistEnd ) {
        // 初始未选中状态
        dayModel.dayState = LLCalendarDayStateSelectStart;
        _isAlreadyExistEnd = NO;
        _isAlreadyExistStart = YES;
        _recordIndexPaths[startIndexPathKey] = indexPath;
        [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
    }
}

// weekDay subview 属性设置
- (void)weekDayViewSubViewPropertySetting {
    _weekDayView.backgroundColor = self.configuration.weekDayHeaderConfiguration.weekDayHeaderBackgroundColor ?:[UIColor colorWithRed:250/255.0f green:250/255.0f blue:250/255.0f alpha:1];
    __weak typeof(self) weakSelf = self;
    [self.weekDayView.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        if ([obj isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)obj;
            if (idx == 0 ||
                idx == 6) {
                label.textColor = strongSelf.configuration.weekDayHeaderConfiguration.weekendHeaderTextColor ?:[UIColor colorWithRed:51/255.0f green:51/255.0f blue:51/255.0f alpha:1];
                label.font = strongSelf.configuration.weekDayHeaderConfiguration.weekendHeaderTextFont ?:[UIFont systemFontOfSize:15];
            } else {
                label.textColor = strongSelf.configuration.weekDayHeaderConfiguration.weekDayHeaderTextColor ?:[UIColor colorWithRed:51/255.0f green:51/255.0f blue:51/255.0f alpha:1];
                label.font = strongSelf.configuration.weekDayHeaderConfiguration.weekDayHeaderTextFont ?:[UIFont systemFontOfSize:15];
            }
        }
    }];
}

// 根据indexPatch 获得 LLCalendarDayModel 对象
- (LLCalendarDayModel *)dayModelForIndexPath:(NSIndexPath *)indexPath {
    LLCalendarMonthModel *monthModel = self.dataArray[indexPath.section];
    LLCalendarDayModel *dayModel = monthModel.dayModels[indexPath.row];
    return dayModel;
}

#pragma mark - getter
- (NSMutableArray *)dataArray {
    if (!_dataArray) {
        _dataArray = NSMutableArray.array;
    }
    return _dataArray;
}

- (UIView *)weekDayView {
    if (!_weekDayView) {
        _weekDayView = UIView.new;
        _weekDayView.backgroundColor = [UIColor colorWithRed:250/255.0f green:250/255.0f blue:250/255.0f alpha:1];
        _weekDayView.frame = CGRectMake(0, 0, self.bounds.size.width, kLayoutScale(35));
        
        CGFloat labelW = CGRectGetWidth(_weekDayView.frame) / 7;
        CGFloat labelH = CGRectGetHeight(_weekDayView.frame);
        NSArray *weeks = @[@"日",@"一",@"二",@"三",@"四",@"五",@"六"];
        for (int i = 0; i < weeks.count; i++) {
            UILabel *label = UILabel.new;
            label.text = weeks[i];
            label.textColor = [UIColor colorWithRed:51/255.0f green:51/255.0f blue:51/255.0f alpha:1];
            label.font = [UIFont systemFontOfSize:15];
            label.frame = CGRectMake(i * labelW, 0, labelW, labelH);
            label.textAlignment = NSTextAlignmentCenter;
            [_weekDayView addSubview:label];
        }
    }
    return _weekDayView;
}

- (UICollectionView *)collectionView {
    if (!_collectionView) {
        // 自定义布局
        LLCalendarMonthCollectionViewLayout *layout = [LLCalendarMonthCollectionViewLayout new];
        
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(self.weekDayView.frame), self.frame.size.width, CGRectGetHeight(self.frame) - CGRectGetMaxY(self.weekDayView.frame)) collectionViewLayout:layout];
        [_collectionView registerClass:[LLCalendarCollectionCell class] forCellWithReuseIdentifier:@"LLCalendarCollectionCell"];
        [_collectionView registerClass:[LLCalendarMonthCollectionSectionHeader class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"LLCalendarMonthCollectionSectionHeader"];
        _collectionView.delegate = self;
        _collectionView.dataSource = self;
        _collectionView.showsVerticalScrollIndicator = NO;
        _collectionView.backgroundColor = [UIColor whiteColor];
    }
    return _collectionView;
}

@end


@implementation LLCalendarViewConfiguration


@end




