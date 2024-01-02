//
//  ViewController.swift
//  MapG
//
//  Created by SENTIENTGEEKS on 02/01/24.
//

import UIKit
import MapKit
import CoreData
class ViewController: UIViewController{
    
    @IBOutlet weak var mapView: MKMapView!
    
    var exitRegionTimer : Timer?
    let locationManager = CLLocationManager()
    var locations : [CLLocation] = []
    // core data
    lazy var persistentContainer : NSPersistentContainer = {
         let container = NSPersistentContainer(name: "MapG")
        container.loadPersistentStores(completionHandler: {(_, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        mapView.delegate = self
        
        // Do any additional setup after loading the view.
    }
    @IBAction func addGeofence(_ sender: Any) {
        guard let longPress = sender as? UILongPressGestureRecognizer else { return }
              let touchLocation = longPress.location(in: mapView)
              let coordinate = mapView.convert(touchLocation, toCoordinateFrom: mapView)
        // add geofence to viewmodel
              let region = CLCircularRegion(center: coordinate, radius: 10000, identifier: "geofence")
              mapView.removeOverlays(mapView.overlays)
              locationManager.startMonitoring(for: region)
              let circle = MKCircle(center: coordinate, radius: region.radius)
        mapView.addOverlay(circle)
    }
    func showAlert(title: String, message: String) {
           let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
           let action = UIAlertAction(title: "OK", style: .default, handler: nil)
           alert.addAction(action)
//           present(alert, animated: true, completion: nil)
        present(alert, animated: true) {
               // Dismiss the alert after 5 seconds
               DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                   alert.dismiss(animated: true, completion: nil)
               }
           }
       }
    func showNotification(title: String, message: String) {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            content.badge = 1
        content.sound = .default
            let request = UNNotificationRequest(identifier: "notif", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
    func startExiteRegionTimer(){
        exitRegionTimer = Timer.scheduledTimer(timeInterval: 120, target: self, selector: #selector(handleExitRegionTimer), userInfo: nil, repeats: true)
    }
    @objc func handleExitRegionTimer() {
        // Record the latitude and longitude data to Core Data
        if let lastLocation = locations.last {
            saveLocationToCoreData(location : lastLocation)
            print("Saved location to Core Data - Latitude: \(lastLocation.coordinate.latitude), Longitude: \(lastLocation.coordinate.longitude)")
        }
        // this function will be called every 2 minutes when the user is outside the geofence region
        let title = "Still outside the Region"
        let message = "You are outside the geofence area."
        showAlert(title: title, message: message)
        
    }
    func saveLocationToCoreData(location : CLLocation) {
        let context = persistentContainer.viewContext
        let entity = NSEntityDescription.entity(forEntityName: "UserLocation", in: context)
        let userLocation = NSManagedObject(entity: entity!, insertInto: context)
        
        userLocation.setValue(location.coordinate.latitude, forKey: "latitude")
        userLocation.setValue(location.coordinate.longitude, forKey: "longitude")
        userLocation.setValue(Date(), forKey: "timestamp")
        
        do{
            try context.save()
        }catch{
            print("Faild to save location data : \(error.localizedDescription)")
        }
    }
}
//MARK: - CLLocationManagerDelegate

extension ViewController : CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.last?.coordinate else {
                    return
                }
                // Stop updating location to conserve battery
//                locationManager.stopUpdatingLocation()
        let location = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                // Add a marker at the user's current location
                let annotation = MKPointAnnotation()
                annotation.coordinate = userLocation
                annotation.title = "Your Location"
                mapView.addAnnotation(annotation)
                
                // Zoom to the user's location
                let region = MKCoordinateRegion(center: userLocation, latitudinalMeters: 500, longitudinalMeters: 500)
                mapView.setRegion(region, animated: true)
                
                mapView.showsUserLocation = true
        self.locations.append(location)
    }
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
          let title = "You Entered the Region"
          let message = "Wow theres you in here! YAY!"
          showAlert(title: title, message: message)
          showNotification(title: title, message: message)
        exitRegionTimer?.invalidate()
        exitRegionTimer = nil
      }
      
      func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
          let title = "You Left the Region"
          let message = " bye bye =["
          showAlert(title: title, message: message)
          showNotification(title: title, message: message)
          // Stop the timer when entering the region
         startExiteRegionTimer()
      }
}

//MARK: - MKMapViewDelegate

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let circleOverlay = overlay as? MKCircle else { return MKOverlayRenderer() }
        let circleRenderer = MKCircleRenderer(circle: circleOverlay)
        circleRenderer.strokeColor = .red
        circleRenderer.fillColor = .red
        circleRenderer.alpha = 0.5
        return circleRenderer
    }
}
