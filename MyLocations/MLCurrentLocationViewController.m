//
//  MLFirstViewController.m
//  MyLocations
//
//  Created by Anne West on 9/23/14.
//  Copyright (c) 2014 TDG. All rights reserved.
//

#import "MLCurrentLocationViewController.h"

@interface MLCurrentLocationViewController ()
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;
@property (weak, nonatomic) IBOutlet UILabel *latitudeLabel;
@property (weak, nonatomic) IBOutlet UILabel *longitudeLabel;
@property (weak, nonatomic) IBOutlet UILabel *addressLabel;
@property (weak, nonatomic) IBOutlet UIButton *tagButton;
@property (weak, nonatomic) IBOutlet UIButton *getButton;

//Object that will give the GPS coordinates. Created in initWithCoder
@property (nonatomic, strong) CLLocationManager *locationManager;

//if location is actively being updated
@property (nonatomic) BOOL updatingLocation;

//location retrieved
@property (nonatomic, strong) CLLocation *location;

//error if happens
@property (nonatomic, strong) NSError *lastLocationError;

//properties for reverse geocoding
@property (nonatomic, strong) CLGeocoder *geocoder;//object that does reverse geocoding
@property (nonatomic, strong) CLPlacemark *placemark;//holds address results
@property (nonatomic) BOOL performingReverseGeocoding;
@property (nonatomic,strong) NSError *lastGeocodingError;

@end

@implementation MLCurrentLocationViewController

- (instancetype) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.geocoder = [[CLGeocoder alloc] init];
    }
    return self;
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [self updateLabels];
    [self configureGetButton];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)getLocation:(UIButton *)sender {
    
    if (self.updatingLocation) {
        [self stopLocationManager];
    } else {
        self.location = nil;
        self.lastLocationError = nil;
        self.placemark = nil;
        self.lastGeocodingError = nil;
        
        [self startLocationManager];
        
    }
    [self updateLabels];
    [self configureGetButton];
}

#pragma mark - CLLocationManagerDelegate

- (void) locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"didFailWithError: %@", error);
    
    if (error.code == kCLErrorLocationUnknown) {
        return;
    }
    
    [self stopLocationManager];
    self.lastLocationError = error;
    
    
    [self updateLabels];
    [self configureGetButton];
}

- (void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation *newLocation = [locations lastObject];//is an array for locations found and want the most recent
    NSLog(@"didUpdateLocations: %@", newLocation);
    
    //check to see if desired accuracy reached amd turn off searching
    
    //if no new location in last 5 seconds, keep going
    if ([newLocation.timestamp timeIntervalSinceNow] < -5) {
        return;
    }
    
    //if we're getting an anomolous reading, keep going
    if (newLocation.horizontalAccuracy < 0) {
        return;
    }
    
    //prepare to do some checking about distance between observations
    CLLocationDistance distance = MAXFLOAT;//if just got started
    if (self.location) {
        distance = [newLocation distanceFromLocation: self.location];
    }
    
    //if the location is not nil (searching just started) or the last reading is more accurate than the stored location, reset the stored location
    //here is where problem was if don't reset location to nil.  Horizontal accuracy from last run never meets this condition
    if (self.location == nil || self.location.horizontalAccuracy > newLocation.horizontalAccuracy) {
        self.location = newLocation;//update the stored location
        self.lastLocationError = nil;//wipe out the last error
        [self updateLabels];
        
        //now check if we have reached the target accuracy and stop if true
        if (newLocation.horizontalAccuracy <= self.locationManager.desiredAccuracy) {
            NSLog(@"We're done");
            [self stopLocationManager];
            [self configureGetButton];
            
            //if locations don't match, force a geocode
            if (distance > 0) {
                self.performingReverseGeocoding = NO;
            }
        }
        
        if (!self.performingReverseGeocoding) {
            NSLog(@"Going to geocode");
            self.performingReverseGeocoding = YES;
            
            [self.geocoder reverseGeocodeLocation:self.location
                                completionHandler:^(NSArray *placemarks, NSError *error) {
                
                NSLog(@"Found placemarks: %@, error %@", placemarks, error);
                self.lastGeocodingError = error;
                
                if (!error && [placemarks count] > 0) {
                    self.placemark = [placemarks lastObject];
                } else {
                    self.placemark = nil;
                }
                self.performingReverseGeocoding = NO;
                [self updateLabels];
            }];
        }
    //if no longer getting better accuracy but location is close
    } else if (distance < 1.0){
        //if it's been more than 10 seconds since we last updated self.location
        NSTimeInterval timeInterval = [newLocation.timestamp timeIntervalSinceDate:self.location.timestamp];
        if (timeInterval > 10) {
            NSLog(@"Force done");
            [self stopLocationManager];
            [self updateLabels];
            [self configureGetButton];
        }
    }
    

}

- (NSString *) stringFromPlacemark: (CLPlacemark *) thePlacemark
{
    return [NSString stringWithFormat:@"%@ %@\n%@ %@ %@", thePlacemark.subThoroughfare, thePlacemark.thoroughfare, thePlacemark.locality, thePlacemark.administrativeArea, thePlacemark.postalCode];
}
- (void) updateLabels
{
    //update the values
    
    //if there is a location found
    if (self.location) {
        self.latitudeLabel.text = [NSString stringWithFormat:@"%.8f", self.location.coordinate.latitude];
        self.longitudeLabel.text = [NSString stringWithFormat:@"%.8f", self.location.coordinate.longitude];
        self.tagButton.hidden = NO;
        self.messageLabel.text = @"";
        NSLog(@"message label %@", self.messageLabel.text);
        
        if (self.placemark) {
            self.addressLabel.text = [self stringFromPlacemark: self.placemark];
        } else if (self.performingReverseGeocoding){
            self.addressLabel.text = @"Searching for address";
        } else if (self.lastGeocodingError) {
            self.addressLabel.text = @"Error finding address";
        } else {
            self.addressLabel.text = @"No address found";
        }
    
    //if no location found
    } else {
        self.latitudeLabel.text = @"";
        self.longitudeLabel.text = @"";
        self.addressLabel.text = @"";
        self.tagButton.hidden = YES;

        //update the status message
        NSString *statusMessage;
        
        //if there is an error
        if (self.lastLocationError != nil) {
            //if the error indicates that location services off for this app
            if ([self.lastLocationError.domain isEqualToString:kCLErrorDomain] && self.lastLocationError.code == kCLErrorDenied) {
                NSLog(@"disabled error");
                statusMessage = @"Location Services Disabled";
            //otherwise error is getting a location
            } else {
                statusMessage = @"Error Getting Location";
                NSLog(@"status %@", statusMessage);
            }
        //if not an error but location services not enabled at all
        } else if (![CLLocationManager locationServicesEnabled]) {
            statusMessage = @"Location Services Disabled";
        //if no error and actively searching
        } else if (self.updatingLocation) {
            statusMessage = @"Searching . . .";
        //if here, haven't started to search yet
        } else {
            statusMessage = @"Press Button to Find Location.";
        }
        
        self.messageLabel.text = statusMessage;
    }
    
}

- (void) configureGetButton
{
    if (self.updatingLocation) {
        [self.getButton setTitle:@"Stop" forState:UIControlStateNormal];
    } else {
        [self.getButton setTitle:@"Get Location" forState:UIControlStateNormal];
    }
}

-(void) didTimeOut: (id) obj
{
    NSLog(@"Time out");
    
    if (!self.location) {
        [self stopLocationManager];
        
        //Need to establisha custome error domain and assign an error code
        self.lastLocationError = [NSError errorWithDomain:@"MyLocationsErrorDomain" code:1 userInfo:nil];
        
        [self updateLabels];
        [self configureGetButton];
    }
    
}

- (void) startLocationManager
{
    if ([CLLocationManager locationServicesEnabled]) {
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
        [self.locationManager startUpdatingLocation];//now the locationManager wil start sending updates to self, as the delegate
        //self.location = nil;//added this to be able to search for a new location. Not in tutorial
        
        self.updatingLocation = YES;
        
        //schedule a call to selector to cancel location searching if has been going for a minute
        [self performSelector:@selector(didTimeOut:) withObject:nil afterDelay:60];
    }
}

- (void) stopLocationManager
{
    if (self.updatingLocation) {
        //cancel the call to selector if have stopped
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(didTimeOut:) object:nil];
        [self.locationManager stopUpdatingLocation];
        self.locationManager.delegate = nil;
        self.updatingLocation = NO;
    }
}

@end
