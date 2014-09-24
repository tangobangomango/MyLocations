//
//  MLFirstViewController.h
//  MyLocations
//
//  Created by Anne West on 9/23/14.
//  Copyright (c) 2014 TDG. All rights reserved.
//

#import <UIKit/UIKit.h>

//To use location services, need to have this framework installed, imported here, and controller designated as a delegate
#import <CoreLocation/CoreLocation.h>

@interface MLCurrentLocationViewController : UIViewController <CLLocationManagerDelegate>

@end
