//
//  CSMachine.m
//  Clock Signal
//
//  Created by Thomas Harte on 04/01/2016.
//  Copyright © 2016 Thomas Harte. All rights reserved.
//

#import "CSMachine.h"
#import "CSMachine+Subclassing.h"

struct SpeakerDelegate: public Outputs::Speaker::Delegate {
	__weak CSMachine *machine;
	void speaker_did_complete_samples(Outputs::Speaker *speaker, const int16_t *buffer, int buffer_size) {
		[machine speaker:speaker didCompleteSamples:buffer length:buffer_size];
	}
};

typedef NS_ENUM(NSInteger, CSAtari2600RunningState) {
	CSMachineRunningStateRunning,
	CSMachineRunningStateStopped
};

@implementation CSMachine {
	SpeakerDelegate _speakerDelegate;

	dispatch_queue_t _serialDispatchQueue;
	NSConditionLock *_runningLock;
}

- (void)perform:(dispatch_block_t)action {
	dispatch_async(_serialDispatchQueue, action);
}

- (void)speaker:(Outputs::Speaker *)speaker didCompleteSamples:(const int16_t *)samples length:(int)length {
	[self.audioQueue enqueueAudioBuffer:samples numberOfSamples:(unsigned int)length];
}

- (void)runForNumberOfCycles:(int)cycles {
	if([_runningLock tryLockWhenCondition:CSMachineRunningStateStopped]) {
		[_runningLock unlockWithCondition:CSMachineRunningStateRunning];
		dispatch_async(_serialDispatchQueue, ^{
			[_runningLock lockWhenCondition:CSMachineRunningStateRunning];
			[self doRunForNumberOfCycles:cycles];
			[_runningLock unlockWithCondition:CSMachineRunningStateStopped];
		});
	}
}

- (instancetype)init {
	self = [super init];

	if (self) {
		_serialDispatchQueue = dispatch_queue_create("Machine queue", DISPATCH_QUEUE_SERIAL);
		_runningLock = [[NSConditionLock alloc] initWithCondition:CSMachineRunningStateStopped];

		_speakerDelegate.machine = self;
		[self setSpeakerDelegate:&_speakerDelegate sampleRate:44100];
	}

	return self;
}

- (BOOL)setSpeakerDelegate:(Outputs::Speaker::Delegate *)delegate sampleRate:(int)sampleRate {
	return NO;
}
- (void)doRunForNumberOfCycles:(int)numberOfCycles {}

@end
