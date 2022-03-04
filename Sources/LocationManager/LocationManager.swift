
import UIKit
import CoreLocation


public protocol LocationManagerDelegate : NSObjectProtocol {
    func locationManager(_ manager: LocationManager, didChangePermissions permission: LocationPermission)
    func locationManager(_ manager: LocationManager, didUpdateCoordinates coordinates: CLLocationCoordinate2D)
    func locationManager(_ manager: LocationManager, didFailWithError error: NSError)
    func locationManager(_ manager: LocationManager, didUpdateCityName cityName: String)
}

public extension LocationManagerDelegate {
    func locationManager(_ manager: LocationManager, didUpdateCityName: String) {}
}

public enum LocationPermission {
    case always
    case whenInUse
    case denied
    case notDetermined
}

public enum NeededLocationPermission {
    case always
    case whenInUse
}

public enum LocationAccuracy {
    case bestForNavigation
    case best
    case tenMeters
    case hundredMeters
    case oneKilometer
    case threeKilometers
}



// MARK: - Location Manager

public class LocationManager: NSObject, CLLocationManagerDelegate {

    fileprivate var location: CLLocationCoordinate2D!
    fileprivate var currentCityName: String!
    fileprivate var currentLocationPermissions: LocationPermission = .notDetermined
    fileprivate var startUpdatingLocationAfterAuthorized: Bool! = false
    
    fileprivate var locationManager: CLLocationManager!
    fileprivate var locationDelegates: [LocationManagerDelegate] = []

    public var neededLocationPermission: NeededLocationPermission = .whenInUse
    public var locationAccuracy: LocationAccuracy = .tenMeters
    public var allowsBackgroundLocationUpdates: Bool = false
    
    public static let shared = LocationManager()
    
    
    fileprivate override init() {
        super.init()
        
        if self.locationManager == nil {
            self.locationManager = CLLocationManager()
            self.locationManager.delegate = self
            self.currentCityName = nil
        }
    }
    
    
    // MARK: Add / Remove Delegates
    
    public func addDelegate(_ delegate: LocationManagerDelegate) {
        
        for currentDelegate in self.locationDelegates {
            if currentDelegate.isEqual(delegate) {
                return
            }
        }
                
        self.locationDelegates.append(delegate)
    }
    
    public func removeDelegate(_ delegate: LocationManagerDelegate) {
        
        for i in 0 ..< self.locationDelegates.count {
            let currentDelegate = self.locationDelegates[i]
            
            if currentDelegate.isEqual(delegate) {
                self.locationDelegates.remove(at: i)
                
                if self.locationDelegates.count == 0 {
                    self.stopUpdatingLocation()
                }
                
                return
            }
        }
    }

    public func removeAllDelegates() {
        self.locationDelegates.removeAll()
        self.stopUpdatingLocation()
    }
    
    
    // MARK: Check status
    
    // Location
    
    public func hasLocation() -> Bool {
        return self.locationManager.location != nil
    }
    
    // Authorization
    
    public func hasAnyAuthorization() -> Bool {
        return self.hasAlwaysAuthorization() || self.hasWhenInUseAuthorization()
    }
    
    public func hasAlwaysAuthorization() -> Bool {
        return CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedAlways
    }
    
    public func hasWhenInUseAuthorization() -> Bool {
        return CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedWhenInUse
    }
    
    public func hasDeterminedAuthorization() -> Bool {
        return CLLocationManager.authorizationStatus() != .notDetermined
    }
    
    
    // MARK: Location
    
    // Getters
    
    public func getCurrentLocation() -> CLLocationCoordinate2D? {
        return self.locationManager.location?.coordinate
    }
    
    public func getCurrentCityName() -> String {
        return self.currentCityName
    }
    
    
    // Update
    
    func startUpdatingLocation() {
        self.startUpdatingLocationIfAuthorized()
    }
    
    func stopUpdatingLocation() {
        self.locationManager.stopUpdatingLocation()
    }
    
    fileprivate func startUpdatingLocationIfAuthorized() {
        if !self.hasAnyAuthorization() {
            self.requestLocationAuthorizationUpdatingLocation()
        } else {
            self.runLocationUpdate()
        }
    }
    
    
    // Permissions
    
    public func getCurrentLocationPermissions() -> LocationPermission {
        return self.currentLocationPermissions
    }
    
    public func requestLocationAuthorization() {
        self.startUpdatingLocationAfterAuthorized = false
        
        if !self.hasAnyAuthorization() {
            switch neededLocationPermission {
            case .always:
                self.locationManager.requestAlwaysAuthorization()
            case .whenInUse:
                self.locationManager.requestWhenInUseAuthorization()
            }
        }
    }
    
    fileprivate func requestLocationAuthorizationUpdatingLocation() {
        self.startUpdatingLocationAfterAuthorized = true
        
        if !self.hasAnyAuthorization() {
            switch neededLocationPermission {
            case .always:
                self.locationManager.requestAlwaysAuthorization()
            case .whenInUse:
                self.locationManager.requestWhenInUseAuthorization()
            }
        }
    }
    
    
    // MARK: Run Location Update
    
    fileprivate func runLocationUpdate() {
        switch self.locationAccuracy {
        case .bestForNavigation:
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            self.locationManager.distanceFilter = 2
            
        case .best:
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            self.locationManager.distanceFilter = 5
            
        case .tenMeters:
            self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            self.locationManager.distanceFilter = 10
            
        case .hundredMeters:
            self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            self.locationManager.distanceFilter = 35
            
        case .oneKilometer:
            self.locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
            self.locationManager.distanceFilter = 300
            
        case .threeKilometers:
            self.locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            self.locationManager.distanceFilter = 1000
        }
        
        self.locationManager.pausesLocationUpdatesAutomatically = false
        self.locationManager.activityType = .automotiveNavigation
        
        if #available(iOS 9.0, *) {
            self.locationManager.allowsBackgroundLocationUpdates = self.allowsBackgroundLocationUpdates
        }
        
        self.locationManager.startUpdatingLocation()
    }
    
    
    // MARK: - Location Manager Delegate
    
    // Authorization
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        switch status {
            case .authorizedAlways:
                self.currentLocationPermissions = .always
            case .authorizedWhenInUse:
                self.currentLocationPermissions = .whenInUse
            default:
                self.currentLocationPermissions = .denied
        }
        
        
        if self.locationDelegates.count == 0 {
            self.stopUpdatingLocation()
            return
        }
        
        for delegate in self.locationDelegates {
            delegate.locationManager(self, didChangePermissions: self.currentLocationPermissions)
        }
        
        if self.hasAnyAuthorization() && self.startUpdatingLocationAfterAuthorized {
            self.runLocationUpdate()
        }
    }
    
    // Location
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        if self.locationDelegates.count == 0 {
            self.stopUpdatingLocation()
            return
        }
                
        let newLocation = locations[0]
        self.location = newLocation.coordinate
        
        for delegate in self.locationDelegates {
            delegate.locationManager(self, didUpdateCoordinates: self.location)
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        for delegate in self.locationDelegates {
            delegate.locationManager(self, didFailWithError: error as NSError)
        }
    }
    
    
    // MARK: - Get City Name
    
    public func updateCurrentCityName() {
        let geoCoder: CLGeocoder = CLGeocoder()
        let currentLocation: CLLocation = CLLocation(latitude: self.location.latitude, longitude: self.location.longitude)
        
        geoCoder.reverseGeocodeLocation(currentLocation) { [unowned self] (placemarks, error) in
            if let placemarks = placemarks, placemarks.count > 0 {
                
                let firstPlaceMark: CLPlacemark = placemarks.first!
                self.currentCityName = firstPlaceMark.locality!
            }
            
            for delegate in self.locationDelegates {
                delegate.locationManager(self, didUpdateCityName: self.currentCityName)
            }
        }
    }
    
}
