//
//  ViewController.m
//  Nearby Cabs
//
//  Created by Param Aggarwal on 26/02/15.
//  Copyright (c) 2015 Param. All rights reserved.
//

#import "ViewController.h"
#import <CoreLocation/CoreLocation.h>
#import <SIOSocket/SIOSocket.h>

@interface ViewController () <CLLocationManagerDelegate, MKMapViewDelegate>

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) SIOSocket *socket;
@property (strong, nonatomic) NSMutableArray *markers;
@property (assign, nonatomic) CLLocationCoordinate2D currentPosition;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.markers = [NSMutableArray array];
    
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    // Check for iOS 8. Without this guard the code will crash with "unknown selector" on iOS 7.
    if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [self.locationManager requestWhenInUseAuthorization];
    }
    [self.locationManager startUpdatingLocation];
    
    __block ViewController *pself = self;
    [SIOSocket socketWithHost:@"http://Params-MacBook-Pro.local:3000" response:^(SIOSocket *socket) {
        self.socket = socket;
//        NSLog(@"%@", socket);
        
        [self.socket setOnConnect:^{
            NSLog(@"client connected to server");
            
            [pself.socket emit:@"log" args:@[@"Hi, server!"]];
        }];
        
        [pself.socket setOnDisconnect:^{
            NSLog(@"client disconnected from server");
        }];
        
        [pself.socket setOnError:^(NSDictionary *error) {
            NSLog(@"%@", error);
        }];
        
        [pself.socket on:@"log" callback:^(NSArray *args) {
            NSLog(@"%@", args);
        }];
        
        if (pself.currentPosition.latitude > 0) {
            [pself.socket emit:@"position" args:@[@{
                                                   @"latitude": [NSNumber numberWithFloat:pself.currentPosition.latitude],
                                                   @"longitude": [NSNumber numberWithFloat:pself.currentPosition.longitude],
                                                   @"distance": @2000
                                                   }]];
        }
        
        [pself.socket on:@"markers" callback:^(NSArray *args) {
            NSArray *markers = args[0];

            NSMutableArray *storedMarkers = [NSMutableArray array];
            [markers enumerateObjectsUsingBlock:^(NSDictionary *marker, NSUInteger idx, BOOL *stop) {
                NSDictionary *markerData = marker[@"doc"];
                
                NSNumber *latitude = markerData[@"position"][@"coordinates"][1];
                NSNumber *longitude = markerData[@"position"][@"coordinates"][0];
                CLLocationCoordinate2D position = CLLocationCoordinate2DMake([latitude floatValue], [longitude floatValue]);
                
                MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
                [annotation setCoordinate:position];
                
                [storedMarkers addObject:@{
                                           @"id": markerData[@"id"],
                                           @"annotation": annotation
                                           }];
                [self.mapView addAnnotation:annotation];
            }];

            NSLog(@"Markers: %@", storedMarkers);
            self.markers = storedMarkers;
        }];
        
        [pself.socket on:@"update" callback:^(NSArray *args) {
            NSLog(@"Update: %@", args);
            NSDictionary *updatedMarker = args[0][@"new_val"];

            NSMutableArray *storedMarkers = [NSMutableArray array];
            [pself.markers enumerateObjectsUsingBlock:^(NSDictionary *marker, NSUInteger idx, BOOL *stop) {

                NSString *markerId = marker[@"id"];
                if ([markerId isEqualToString:updatedMarker[@"id"]]) {
                    
                    NSNumber *latitude = updatedMarker[@"position"][@"coordinates"][1];
                    NSNumber *longitude = updatedMarker[@"position"][@"coordinates"][0];
                    CLLocationCoordinate2D position = CLLocationCoordinate2DMake([latitude floatValue], [longitude floatValue]);
                    
                    MKPointAnnotation *annotation = marker[@"annotation"];
                    [annotation setCoordinate:position];
                    
                    [storedMarkers addObject:@{
                                               @"id": updatedMarker[@"id"],
                                               @"annotation": annotation
                                               }];
                } else {
                    [storedMarkers addObject:marker];
                }
            }];
            
            NSLog(@"Markers: %@", storedMarkers);
            self.markers = storedMarkers;
        }];
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Location Manager Delegate Methods
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    [self.locationManager stopUpdatingLocation];

    CLLocation *location = [locations lastObject];
//    NSLog(@"%@, %f, %f", location, location.coordinate.latitude, location.coordinate.longitude);
    
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(location.coordinate.latitude, location.coordinate.longitude);
    MKCoordinateSpan span = MKCoordinateSpanMake(0.1f, 0.1f);
    MKCoordinateRegion region = [self.mapView regionThatFits:MKCoordinateRegionMake(coordinate, span)];
    [self.mapView setRegion:region animated:YES];
    
    // Place a single pin
//    MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
//    [annotation setCoordinate:coordinate];
//    [self.mapView addAnnotation:annotation];

    if (self.socket) {
        [self.socket emit:@"nearby" args:@[@{
                                               @"latitude": [NSNumber numberWithFloat:location.coordinate.latitude],
                                               @"longitude": [NSNumber numberWithFloat:location.coordinate.longitude],
                                               @"distance": @2000
                                               }]];
    } else {
        self.currentPosition = CLLocationCoordinate2DMake(location.coordinate.latitude, location.coordinate.longitude);
    }
    
}

@end
