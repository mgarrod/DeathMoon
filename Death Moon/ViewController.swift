//
//  ViewController.swift
//  Death Moon
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
    // to use esri location manager
    //let trackingLocationDataSource = AGSCLLocationDataSource()
    private let arView = ArcGISARView()
    private let graphicsOverlay = AGSGraphicsOverlay()
    // nice pod for moon stuff
    //https://github.com/cristiangonzales/SwiftySuncalc
    // based on
    //https://github.com/mourner/suncalc
    let suncalc: SwiftySuncalc! = SwiftySuncalc()
    // deathstar image is 800x800
    //https://dlpng.com/png/5510573
    //https://www.pixelsquid.com/png/death-star-1122530576553744216
    var deathMoonSymbol = AGSPictureMarkerSymbol(image: UIImage(named: "deathstar")!)
    // illumination
    var fraction = 1.0
    // waxing / waning
    var waxing = true
    // angle of the shadow on the moon
    var angle = 0.0
    var illuminationAngle = Double.nan
    var parallacticAngle = 0.0
    // label to display data
    var thelabel: UILabel!
    // used for display to show the devices haeding
    var heading = "---"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        // setup AR view
        arView.translatesAutoresizingMaskIntoConstraints = false
        arView.locationDataSource = AGSCLLocationDataSource()
        // to use esri location manager
//        trackingLocationDataSource.locationChangeHandlerDelegate = self
//        trackingLocationDataSource.start()
        view.addSubview(arView)
        NSLayoutConstraint.activate([
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        
        // finish setting up the AR view for real-world
        configureSceneForAR()
        
        // Ask for Authorisation from the User.
        self.locationManager.requestAlwaysAuthorization()

        // For use in foreground
        self.locationManager.requestWhenInUseAuthorization()

        // start location tracking
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        }
        
        // setup the label for spec display in the bottom right
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
        
        // update the image every 30 seconds and restart location manager. Do not want to update every time the position changes because of all it does.
        _ = Timer.scheduledTimer(timeInterval: 30.0, target: self, selector: #selector(setupImage), userInfo: nil, repeats: true)

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // start tracking for AR - I use continuous tracking. Works best while walking / driving around
        //arView.startTracking(.initial, completion: nil)
        arView.startTracking(.continuous, completion: nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // stop tracking AR
        arView.stopTracking()
    }
    
    private func configureSceneForAR() {
        // Create scene with imagery basemap
        let scene = AGSScene(basemapType: .imagery)
        
        // Create an elevation source and add it to the scene
        // I decided not to use it since I am not place things on the surface
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
        
        // add the graphucs layer to the scene
        arView.sceneView.graphicsOverlays.add(graphicsOverlay)
        
        // check surface placement
        // Treat the Z values as absolute altitude values
        graphicsOverlay.sceneProperties?.surfacePlacement = .absolute
        
    }
    
    @objc private func setupImage() {
        
        let today = Date()
//        var yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
//        var yesterday = Calendar.current.date(byAdding: .hour, value: -12, to: today)!
        // get the moon illumination, phase and angle for today.
        let moon = suncalc.getMoonIllumination(date: today)
        fraction = moon["fraction"]! // percent illuminated
        waxing = moon["phase"]! <= 0.5 // 0.0 to 1.0. waxing is <= 0.5
        illuminationAngle = Double(moon["angle"]!)
        // By subtracting the parallacticAngle from the angle one can get the zenith angle of the moons bright limb (anticlockwise). The zenith angle can be used do draw the moon shape from the observers perspective (e.g. moon lying on its back).
        // I suptract 90 from it because of how I rotate the shadow
        angle = (Double.pi / 2) - (illuminationAngle - parallacticAngle)
        angle = angle < 0.0 ? (2 * Double.pi) + angle : angle
        
        // get a new image that will show a shadow based on illumination percent and if it is waxing / waning
        let newImage = drawImage()
        // set the new image to the picture symbol and set the initial height and width to 100x100
        deathMoonSymbol = AGSPictureMarkerSymbol(image: newImage)
        deathMoonSymbol.height = 100
        deathMoonSymbol.width = 100
        deathMoonSymbol.offsetY = 0
        
        // start location manager back up
        locationManager.startUpdatingLocation()
        
        // test graphic
//        let point = AGSPoint(x: -84.47016200393804, y: 39.23550174436833, z: 100, spatialReference: .wgs84())
//        let graphic = AGSGraphic(geometry: point, symbol: deathMoonSymbol, attributes: nil)
//        self.graphicsOverlay.graphics.add(graphic)
        
    }
    
    private func drawImage() -> UIImage {
        
        // Based on a 800x800 image where the drawn part of the image is 780x780
        // This method uses core graphics to draw a shadow on the moon, based on illumination percent and waxing / waning.
        // It uses move(to: CGPoint) and then addCurve(to: CGPoint, control1: CGPoint, control2: CGPoint) to draw the shadow
        // https://developer.apple.com/documentation/uikit/uibezierpath/1624357-addcurve
        // It rotates the shadow based on the user's location and uses simple trig to rotate the to points and control points.
        // It then clips the image, using the drawn graphic. Then it takes the original image, sets the alpha to 0.2 and merges the clipped image and the 0.2 alpha image together.
        // Blurring is also used to try to smooth it
        
        // wanning 50% or more illumination (tie x to left and lessThan50Illumination = false)
        // wanning less than 50% illumination (tie x to right and lessThan50Illumination = true and drag from the left)
        // waxing less than 50% illumination (tie x to left and lessThan50Illumination = true)
        // waxing 50% or more illumination (tie x to right and lessThan50Illumination = true and drag from the left)
        
        // sets the to x position to the left or right of the image
        let tox = (!waxing && fraction < 0.5) || (waxing && fraction >= 0.5) ? 780 : 20
        // if the fraction is less then 50%, subtract the fraction by 1.0. This is used to calculate the points in the algorithm to get points based on illumination
        let reverseFraction = fraction < 0.5 ? 1.0 - fraction : fraction
        
        // start with full moon
        var to1y = 0 // to2y = 800 - (to1y)
        var controlx = 1000 // control 1 and 2 always the same
        var control1y = -200
        
        // algorithm I came up with to set the to / control points based on illumination percent and waxing / waning
        // not 100% happy with it, but it works
        to1y = Int(((reverseFraction-1)*500)*((1-reverseFraction)*10))
        controlx = Int(reverseFraction * 1000.0)
        controlx = (!waxing && fraction < 0.5) || (waxing && fraction >= 0.5) ? 800 - controlx : controlx // control2x = 800 - (control1x)
        control1y = Int(-1*((reverseFraction*170)-((1-reverseFraction)*170)))
        
        var to1x = tox
        var to2x = tox
        var control1x = controlx
        var control2x = controlx
        
        // subtract y1s from 800 to get the y2s, to place them the same distance away from origin
        var to2y = 800-to1y
        var control2y = 800-control1y
        
        // rotate the points based on the angle of the shadow. The center of the image is 400,400 and the upper left is 0,0.
        // To make it eaiser to think about (to make it standard cartesian), I inverse the y for the trig functions and then inverse them back when complete.
        let xorigin = 400
        let yorigin = -400
        // get the ditance from origin
        let to1d = sqrt(pow(Double(xorigin-tox),2)+pow(Double(yorigin-(-1*to1y)),2))
        let to2d = sqrt(pow(Double(xorigin-tox),2)+pow(Double(yorigin-(-1*to2y)),2))
        let control1d = sqrt(pow(Double(xorigin-controlx),2)+pow(Double(yorigin-(-1*control1y)),2))
        let control2d = sqrt(pow(Double(xorigin-controlx),2)+pow(Double(yorigin-(-1*control2y)),2))
        // get the angle of all the points and subtract the angle we want
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
        // get the new points based on distance from origin and the new angle
        to1x = xorigin + Int(to1d * cos(to1angle))
        to1y = -1*(yorigin + Int(to1d * sin(to1angle)))
        to2x = xorigin + Int(to2d * cos(to2angle))
        to2y = -1*(yorigin + Int(to2d * sin(to2angle)))
        control1x = xorigin + Int(control1d * cos(control1angle))
        control1y = -1*(yorigin + Int(control1d * sin(control1angle)))
        control2x = xorigin + Int(control2d * cos(control2angle))
        control2y = -1*(yorigin + Int(control2d * sin(control2angle)))
        
        // set the final points for drawing
        let to1 = CGPoint(x: to1x, y: to1y)
        let to2 = CGPoint(x: to2x, y: to2y)
        let control1 = CGPoint(x: control1x, y: control1y)
        let control2 = CGPoint(x: control2x, y: control2y)
        
        let deathstar = UIImage(named: "deathstar")

        // use core graphics to draw the shadow based on the to / control points and clip the image
        let s = deathstar!.size
        UIGraphicsBeginImageContext(s);
        let g = UIGraphicsGetCurrentContext();
        g!.beginPath()
        g!.move(to: to1)
        g!.addCurve(to: to2, control1: control1, control2: control2)
        // found by mistake. It switches what side is filled in.
        if (fraction < 0.5) {
            g!.addRect(CGRect(x:0,y:0,width:s.width,height:s.height));
        }
        g!.clip(using: CGPathFillRule.evenOdd)
        deathstar!.draw(at: CGPoint.zero)
        let deathstar2 = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        // add alpha and blurring to the images. Top is blurred less and also has a slight alpha applied
        var topImage = deathstar2!.image(alpha: 0.9)
        topImage = topImage!.blurred(radius: 1)
        var bottomImage = UIImage(named: "deathstar")!.image(alpha: 0.2)
        bottomImage = bottomImage!.blurred(radius: 2)
        
        // merge clipped image and alpha 0.2 images together
        UIGraphicsBeginImageContext(s)
        topImage!.draw(in: CGRect(x: 0, y: 0, width: s.width, height: s.height))
        bottomImage!.draw(in: CGRect(x: 0, y: 0, width: s.width, height: s.height))
        let newImage  = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }

    // used to place the image in the correct spot
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let locValue: CLLocationCoordinate2D = manager.location?.coordinate else { return }
        //print("locations = \(locValue.latitude) \(locValue.longitude)")

        //https://github.com/cristiangonzales/SwiftySuncalc
        //https://www.timeanddate.com/moon/@37.46423,-77.67785
        //https://ipgeolocation.io/astronomy-api.html
        //https://www.mooncalc.org/#/37.3686,-78.962,2/2020.12.21/15:53/1/3
        
        if (manager.location!.horizontalAccuracy > -1.0 && manager.location!.horizontalAccuracy < 100.0) {
        
            // need getMoonPosition to set the angle of the cresent before showing the image
            if (illuminationAngle.isNaN) {
                
                //angle = locValue.latitude
                locationManager.stopUpdatingLocation()
                let today = Date()
    //            var yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
    //            var yesterday = Calendar.current.date(byAdding: .hour, value: -12, to: today)!
                let moonPos = suncalc.getMoonPosition(date: today, lat: locValue.latitude, lng: locValue.longitude)
                parallacticAngle = moonPos["parallacticAngle"]!
                setupImage()
            }
            else {

                // get the moons position
                let today = Date()
    //            var yesterday = Calendar.current.date(byAdding: .hour, value: -12, to: today)!
                let moonPos = suncalc.getMoonPosition(date: today, lat: locValue.latitude, lng: locValue.longitude)
                // get the azimuth and altitude for calculations
                // I add 180 to the azimuth because the return is set at 0° in the south and measured azimuth between −180 and +180°
                var azimuth: Double? = moonPos["azimuth"] ?? 0
                azimuth = 180 + (azimuth! * 180 / Double.pi)
                let altitude: Double? = moonPos["altitude"] ?? 0
                parallacticAngle = moonPos["parallacticAngle"]!
                
                // scale the image based on distance from the Earth and its perigee. 100x100 at perigee (363104 km)
                let distance = moonPos["distance"] ?? 400000
                deathMoonSymbol.height = CGFloat((363104 / distance) * 100)
                deathMoonSymbol.width = CGFloat((363104 / distance) * 100)
                deathMoonSymbol.offsetY = 0

                // get a z value, using an adjacent value of 1 kilometer
                let z = 1000 * tan(altitude!)

                // create a point from the current location using the new z value (in meters)
                let point = AGSPoint.init(x: locValue.longitude, y: locValue.latitude, z: z, spatialReference: .wgs84())

                // move the point 1 kilometer away, at the angle (azimuth) of the moon
                // since the z value and the distance away on the x,y plane are both based on a right triangle with an adjacent value of 1 kilometer, the moon is placed in the correct spot.
                let points = AGSGeometryEngine.geodeticMove([point], distance: 1, distanceUnit: .kilometers(), azimuth: azimuth!, azimuthUnit: .degrees(), curveType: .geodesic )

                // set the geometry to the graphic and add it to the graphics layer (first removing it if it exists)
                let graphic = AGSGraphic(geometry: points![0], symbol: deathMoonSymbol, attributes: nil)
                self.graphicsOverlay.graphics.removeAllObjects()
                //if (altitude! > 0) {
                    self.graphicsOverlay.graphics.add(graphic)
                //}

                // show some specs on the screen
                let waxingString = waxing ? "waxing" : "waning";
                thelabel.text = String(format: "azimuth: %.02f°\naltitude: %.02f°\nfraction: %.01f%%\nangle: %.01f%°\nphase: \(waxingString)",azimuth!,altitude! * 180 / Double.pi,fraction * 100,angle * 180 / Double.pi)
    //            thelabel.text = String(format: "my heading: \(heading)°\nazimuth: %.02f°\naltitude: %.02f°\nfraction: %.01f%%\nangle: %.01f%°\nphase: \(waxingString)",azimuth!,altitude! * 180 / Double.pi,fraction * 100,angle * 180 / Double.pi)
                
                // stop the location manager. Don't worry, it will start back up again after 30 seconds to get a new image.
                // This stops the image from bouncing
                locationManager.stopUpdatingLocation()
                
            }
        }
    }
    
    // only used to display the devices haeding on a label
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = String(Int(newHeading.trueHeading))
    }
}

// to use esri location manager
// MARK: - AGSLocationChangeHandlerDelegate
//extension ViewController: AGSLocationChangeHandlerDelegate {
//    func locationDataSource(_ locationDataSource: AGSLocationDataSource, locationDidChange location: AGSLocation) {
//
//        let moonPos = suncalc.getMoonPosition(date: Date(), lat: location.position!.y, lng: location.position!.x)
//
//    }
//}

// extensions to add alpha and blurring to an image
// https://stackoverflow.com/a/37955552
// https://gist.github.com/mxcl/76f40027b1ef515e4e6b41292b54fe92
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

