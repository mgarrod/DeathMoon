//
//  ViewController.swift
//  Death Moon Test
//
//  Created by Garrod, Matthew on 12/20/20.
//  Copyright © 2020 Garrod, Matthew. All rights reserved.
//

import UIKit
import SwiftySuncalc
import CoreLocation
import ARKit
import ArcGISToolkit
import ArcGIS

class ViewController: UIViewController, CLLocationManagerDelegate {

    var locationManager = CLLocationManager()
    //let trackingLocationDataSource = AGSCLLocationDataSource()
    private let arView = ArcGISARView()
    let suncalc: SwiftySuncalc! = SwiftySuncalc()
    var deathMoonSymbol = AGSPictureMarkerSymbol(image: UIImage(named: "deathstar")!)
    var fraction = 1.0
    var waxing = true
    var heading = "---"
    var angle = 100.0
    var doOffset = false
    
    private let graphicsOverlay = AGSGraphicsOverlay()
    
    var thelabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        arView.translatesAutoresizingMaskIntoConstraints = false
        
        arView.locationDataSource = AGSCLLocationDataSource()
        
//        trackingLocationDataSource.locationChangeHandlerDelegate = self
//        trackingLocationDataSource.start()

        view.addSubview(arView)

        NSLayoutConstraint.activate([
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        
        // Ask for Authorisation from the User.
        self.locationManager.requestAlwaysAuthorization()

        // For use in foreground
        self.locationManager.requestWhenInUseAuthorization()

        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        }
        
        configureSceneForAR()
        
        thelabel = UILabel()
        thelabel.numberOfLines = 5
        thelabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(thelabel)

        NSLayoutConstraint.activate([
            thelabel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            thelabel.rightAnchor.constraint(equalTo: view.rightAnchor),
            thelabel.widthAnchor.constraint(equalToConstant: 150),
            thelabel.heightAnchor.constraint(equalToConstant: 200)
        ])
        
//        let button = UIButton(frame: CGRect(x: 20, y: 20, width: 200, height: 60))
//         button.setTitle("offset", for: .normal)
//         button.backgroundColor = .white
//         button.setTitleColor(UIColor.black, for: .normal)
//         button.addTarget(self, action: #selector(self.buttonTapped), for: .touchUpInside)
//         view.addSubview(button)

    }
    
//    @objc func buttonTapped(sender : UIButton) {
//        doOffset = !doOffset
//    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        arView.stopTracking()
    }
    
    private func configureSceneForAR() {
        // Create scene with imagery basemap
        let scene = AGSScene(basemapType: .imagery)
        
        // Create an elevation source and add it to the scene
//        let elevationSource = AGSArcGISTiledElevationSource(url:
//            URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!)
//        scene.baseSurface?.elevationSources.append(elevationSource)

        // Allow camera to go beneath the surface
        scene.baseSurface?.navigationConstraint = .none

        // Display the scene
        arView.sceneView.scene = scene
        arView.sceneView.scene?.baseSurface?.opacity = 0

        // Configure atmosphere and space effect
        arView.sceneView.spaceEffect = .transparent
        arView.sceneView.atmosphereEffect = .none
        
        arView.sceneView.graphicsOverlays.add(graphicsOverlay)
        
        // check surface placement
        // Treat the Z values as absolute altitude values
        graphicsOverlay.sceneProperties?.surfacePlacement = .absolute
        
    }
    
    private func setupImage() {
        
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let moon = suncalc.getMoonIllumination(date: today)
        let moonYesterday = suncalc.getMoonIllumination(date: yesterday)
//        print(moon["fraction"]!)
//        print(CGFloat(moon["phase"]!) * 180 / CGFloat(Double.pi))
        fraction = moon["fraction"]! // percent illuminated
//        print(fraction)
        let fractionYesterday = moonYesterday["fraction"]! // percent illuminated
//        print(fractionYesterday)
//        print(CGFloat(moon["angle"]!) * 180 / CGFloat(Double.pi))
        
        let newImage = drawImage(fraction: fraction, fractionYesterday: fractionYesterday)
        
        deathMoonSymbol = AGSPictureMarkerSymbol(image: newImage)
        
        deathMoonSymbol.height = 100
        deathMoonSymbol.width = 100
        
        // test
//        let point = AGSPoint(x: -84.47016200393804, y: 39.23550174436833, z: 100, spatialReference: .wgs84())
//        let graphic = AGSGraphic(geometry: point, symbol: deathMoonSymbol, attributes: nil)
//        self.graphicsOverlay.graphics.add(graphic)
        
        //arView.startTracking(.initial, completion: nil)
        arView.startTracking(.continuous, completion: nil)
    }
    
    private func drawImage(fraction: Double, fractionYesterday: Double) -> UIImage {
        
        // wanning 50% or more illumination (tie x to left and lessThan50Illumination = false)
        // wanning less than 50% illumination (tie x to right and lessThan50Illumination = true and drag from the left)
        // waxing less than 50% illumination (tie x to left and lessThan50Illumination = true)
        // waxing 50% or more illumination (tie x to right and lessThan50Illumination = true and drag from the left)
        
        waxing = fractionYesterday > fraction ? false : true
        let tox = (!waxing && fraction < 0.5) || (waxing && fraction >= 0.5) ? 780 : 20
        let reverseFraction = fraction < 0.5 ? 1.0 - fraction : fraction
        
        // start with full moon
        var to1y = 0 // to2y = 800 - (to1y)
        var controlx = 1000 // control 1 and 2 always the same
        var control1y = -200
        
        to1y = Int(((reverseFraction-1)*500)*((1-reverseFraction)*10))
        controlx = Int(reverseFraction * 1100.0)
        controlx = (!waxing && fraction < 0.5) || (waxing && fraction >= 0.5) ? 800 - controlx : controlx // control2x = 800 - (control1x)
        control1y = Int(-1*((reverseFraction*200)-((1-reverseFraction)*160)))
        
        var to1x = tox
        var to2x = tox
        var control1x = controlx
        var control2x = controlx
        
        var to2y = 800-to1y
        var control2y = 800-control1y
        
        let xorigin = 400
        let yorigin = -400
        angle = angle * (Double.pi / 180)
        let to1d = sqrt(pow(Double(xorigin-tox),2)+pow(Double(yorigin-(-1*to1y)),2))
        let to2d = sqrt(pow(Double(xorigin-tox),2)+pow(Double(yorigin-(-1*to2y)),2))
        let control1d = sqrt(pow(Double(xorigin-controlx),2)+pow(Double(yorigin-(-1*control1y)),2))
        let control2d = sqrt(pow(Double(xorigin-controlx),2)+pow(Double(yorigin-(-1*control2y)),2))
        
        var to1angle = fmod(atan2(Double((-1*to1y)-yorigin), Double(to1x-xorigin)) + Double.pi * 2, Double.pi * 2)
        to1angle = (to1angle * 180/Double.pi) - (angle * 180/Double.pi)
        to1angle = to1angle < 0 ? 360 + to1angle : to1angle
        to1angle = to1angle * Double.pi / 180
        var to2angle = fmod(atan2(Double((-1*to2y)-yorigin), Double(to2x-xorigin)) + Double.pi * 2, Double.pi * 2)
        to2angle = (to2angle * 180/Double.pi) - (angle * 180/Double.pi)
        to2angle = to2angle < 0 ? 360 + to2angle : to2angle
        to2angle = to2angle * Double.pi / 180
        var control1angle = fmod(atan2(Double((-1*control1y)-yorigin), Double(control1x-xorigin)) + Double.pi * 2, Double.pi * 2)
        control1angle = (control1angle * 180/Double.pi) - (angle * 180/Double.pi)
        control1angle = control1angle < 0 ? 360 + control1angle : control1angle
        control1angle = control1angle * Double.pi / 180
        var control2angle = fmod(atan2(Double((-1*control2y)-yorigin), Double(control2x-xorigin)) + Double.pi * 2, Double.pi * 2)
        control2angle = (control2angle * 180/Double.pi) - (angle * 180/Double.pi)
        control2angle = control2angle < 0 ? 360 + control2angle : control2angle
        control2angle = control2angle * Double.pi / 180
        
        to1x = xorigin + Int(to1d * cos(to1angle))
        to1y = -1*(yorigin + Int(to1d * sin(to1angle)))
        to2x = xorigin + Int(to2d * cos(to2angle))
        to2y = -1*(yorigin + Int(to2d * sin(to2angle)))
        control1x = xorigin + Int(control1d * cos(control1angle))
        control1y = -1*(yorigin + Int(control1d * sin(control1angle)))
        control2x = xorigin + Int(control2d * cos(control2angle))
        control2y = -1*(yorigin + Int(control2d * sin(control2angle)))
        
        let to1 = CGPoint(x: to1x, y: to1y)
        let to2 = CGPoint(x: to2x, y: to2y)
        let control1 = CGPoint(x: control1x, y: control1y)
        let control2 = CGPoint(x: control2x, y: control2y)
        
//        print("to1: ", to1)
//        print("to2: ", to2)
//        print("control1: ", control1)
//        print("control2: ", control2)
        
        let deathstar = UIImage(named: "deathstar")

        //
        let s = deathstar!.size
        UIGraphicsBeginImageContext(s);
        let g = UIGraphicsGetCurrentContext();
        g!.beginPath()
        g!.move(to: to1)
        g!.addCurve(to: to2, control1: control1, control2: control2)
        if (fraction < 0.5) {
            g!.addRect(CGRect(x:0,y:0,width:s.width,height:s.height));
        }
        g!.clip(using: CGPathFillRule.evenOdd)
        deathstar!.draw(at: CGPoint.zero)

        let deathstar2 = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        //
        var topImage = deathstar2!.image(alpha: 0.9)
        topImage = topImage!.blurred(radius: 1)

        var bottomImage = UIImage(named: "deathstar")!.image(alpha: 0.2)
        bottomImage = bottomImage!.blurred(radius: 2)
        
        // merge images together
        UIGraphicsBeginImageContext(s)

        topImage!.draw(in: CGRect(x: 0, y: 0, width: s.width, height: s.height))
        bottomImage!.draw(in: CGRect(x: 0, y: 0, width: s.width, height: s.height))

        let newImage  = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let locValue: CLLocationCoordinate2D = manager.location?.coordinate else { return }
        //print("locations = \(locValue.latitude) \(locValue.longitude)")

        //https://github.com/cristiangonzales/SwiftySuncalc
        //https://www.timeanddate.com/moon/@37.46423,-77.67785
        //https://ipgeolocation.io/astronomy-api.html
        //https://www.mooncalc.org/#/37.3686,-78.962,2/2020.12.21/15:53/1/3
        
        if (angle > 99.0) {
            angle = locValue.latitude
            setupImage()
        }
        else {

            let moonPos = suncalc.getMoonPosition(date: Date(), lat: locValue.latitude, lng: locValue.longitude)

            var azimuth: Double? = moonPos["azimuth"] ?? 0
            //print(azimuth! * 180 / Double.pi)
            azimuth = 180 + (azimuth! * 180 / Double.pi)
            let altitude: Double? = moonPos["altitude"] ?? 0

            let distance = moonPos["distance"] ?? 400000
            deathMoonSymbol.height = CGFloat((363104 / distance) * 100)
            deathMoonSymbol.width = CGFloat((363104 / distance) * 100)
            if (doOffset) {
                deathMoonSymbol.offsetY = -1 * (CGFloat((363104 / distance) * 100) / 2)
            }
            else {
                deathMoonSymbol.offsetY = 0
            }

            // based on 1 kilometer away
            let z = 1000 * tan(altitude!)

            let point = AGSPoint.init(x: locValue.longitude, y: locValue.latitude, z: z, spatialReference: .wgs84())

            let points = AGSGeometryEngine.geodeticMove([point], distance: 1, distanceUnit: .kilometers(), azimuth: azimuth!, azimuthUnit: .degrees(), curveType: .geodesic )

            let graphic = AGSGraphic(geometry: points![0], symbol: deathMoonSymbol, attributes: nil)
            if self.graphicsOverlay.graphics.count > 0 {
                self.graphicsOverlay.graphics.removeObject(at: 0)
            }
            //if (altitude! > 0) {
                self.graphicsOverlay.graphics.add(graphic)
            //}
    //
    //        let graphic2 = AGSGraphic(geometry: points![0], symbol: AGSSimpleMarkerSymbol(style: .triangle, color: .blue, size: 14), attributes: nil)
    //        self.graphicsOverlay.graphics.add(graphic2)

            let waxingString = waxing ? "waxing" : "waning";
            //thelabel.text = String(format: "azimuth: %.02f\naltitude: %.02f\nz: %.02f\nfraction: %d%%\nwaxing: \(waxingString)",azimuth!,altitude! * 180 / Double.pi,z,Int(fraction * 100))
            thelabel.text = String(format: "my heading: \(heading)°\nazimuth: %.02f°\naltitude: %.02f°\nfraction: %.01f%%\nphase: \(waxingString)",azimuth!,altitude! * 180 / Double.pi,fraction * 100)
            
    //        print("azimuth: ", azimuth!)
    //        print("altitude: ", altitude! * 180 / 3.14)
    //        print("z: ", z2)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        
        heading = String(Int(newHeading.trueHeading))
    }
}

// MARK: - AGSLocationChangeHandlerDelegate
//extension ViewController: AGSLocationChangeHandlerDelegate {
//    func locationDataSource(_ locationDataSource: AGSLocationDataSource, locationDidChange location: AGSLocation) {
//
//        //https://github.com/cristiangonzales/SwiftySuncalc
//        //https://www.timeanddate.com/moon/@37.46423,-77.67785
//        //https://ipgeolocation.io/astronomy-api.html
//        //https://www.mooncalc.org/#/37.3686,-78.962,2/2020.12.21/15:53/1/3
//
//        let moonPos = suncalc.getMoonPosition(date: Date(), lat: location.position!.y, lng: location.position!.x)
//
//        var azimuth: Double? = moonPos["azimuth"] ?? 0
//        azimuth = 180 + (azimuth! * 180 / Double.pi)
//        let altitude: Double? = moonPos["altitude"] ?? 0
//
//        let distance = moonPos["distance"] ?? 400000
//        deathMoonSymbol.height = CGFloat((363104 / distance) * 100)
//        deathMoonSymbol.width = CGFloat((363104 / distance) * 100)
//        deathMoonSymbol.offsetY = deathMoonSymbol.image!.size.height / 2
//
//        // based on 1 kilometer away
//        let z = 1000 * tan(altitude!)
//
//        let point = AGSPoint.init(x: location.position!.x, y: location.position!.y, z: z, spatialReference: .wgs84())
//
//        let points = AGSGeometryEngine.geodeticMove([point], distance: 1, distanceUnit: .kilometers(), azimuth: azimuth!, azimuthUnit: .degrees(), curveType: .geodesic )
//
//        let graphic = AGSGraphic(geometry: points![0], symbol: deathMoonSymbol, attributes: nil)
//        if self.graphicsOverlay.graphics.count > 0 {
//            self.graphicsOverlay.graphics.removeObject(at: 0)
//        }
//        //if (altitude! > 0) {
//            self.graphicsOverlay.graphics.add(graphic)
//        //}
//
//        thelabel.text = String(format: "azimuth: %.02f\naltitude: %.02f\nz: %.02f",azimuth!,altitude! * 180 / Double.pi,z)
//
//    }
//}

extension UIImage {
    func image(alpha: CGFloat) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(at: .zero, blendMode: .normal, alpha: alpha)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    func blurred(radius: CGFloat) -> UIImage {
        let ciContext = CIContext(options: nil)
        guard let cgImage = cgImage else { return self }
        let inputImage = CIImage(cgImage: cgImage)
        guard let ciFilter = CIFilter(name: "CIGaussianBlur") else { return self }
        ciFilter.setValue(inputImage, forKey: kCIInputImageKey)
        ciFilter.setValue(radius, forKey: "inputRadius")
        guard let resultImage = ciFilter.value(forKey: kCIOutputImageKey) as? CIImage else { return self }
        guard let cgImage2 = ciContext.createCGImage(resultImage, from: inputImage.extent) else { return self }
        return UIImage(cgImage: cgImage2)
    }
}

