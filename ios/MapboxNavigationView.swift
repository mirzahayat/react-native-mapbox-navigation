import MapboxCoreNavigation
import MapboxDirections
import MapboxNavigation
import Turf

// adapted from https://pspdfkit.com/blog/2017/native-view-controllers-and-react-native/ and https://github.com/mslabenyak/react-native-mapbox-navigation/blob/master/ios/Mapbox/MapboxNavigationView.swift
extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder!.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}

class MapboxNavigationView: UIView, NavigationViewControllerDelegate {
    weak var navViewController: NavigationViewController?
    var embedded: Bool
    var embedding: Bool
    var routesFetched = [Route]()
    
    var totalChucks = 0
    var resultsRecieved = 0
    @objc var waypoints: NSArray = [] {
        didSet { setNeedsLayout() }
    }
    @objc var origin: NSArray = [] {
        didSet { setNeedsLayout() }
    }
    
    @objc var destination: NSArray = [] {
        didSet { setNeedsLayout() }
    }
    
    @objc var shouldSimulateRoute: Bool = false
    @objc var showsEndOfRouteFeedback: Bool = false
    @objc var hideStatusView: Bool = false
    
    @objc var onLocationChange: RCTDirectEventBlock?
    @objc var onRouteProgressChange: RCTDirectEventBlock?
    @objc var onError: RCTDirectEventBlock?
    @objc var onCancelNavigation: RCTDirectEventBlock?
    @objc var onArrive: RCTDirectEventBlock?
    
    override init(frame: CGRect) {
        self.embedded = false
        self.embedding = false
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if (navViewController == nil && !embedding && !embedded) {
            embed()
        } else {
            navViewController?.view.frame = bounds
        }
    }
    
    override func removeFromSuperview() {
        super.removeFromSuperview()
        // cleanup and teardown any existing resources
        self.navViewController?.removeFromParent()
    }
    
    private func embed() {
        guard origin.count == 2 && destination.count == 2 else { return }
        embedding = true
        if (waypoints.count > 0) {
            print("waypointswaypointswaypoints", waypoints.enumerated())
            let lengthForLoop = Int(ceil((Double(waypoints.count)/20)));
            
            let arrayTotalLength = waypoints.count;
            var count = 0;
            var index = 0;
            var newArray = [Any]();
            totalChucks = lengthForLoop
            resultsRecieved = 0
            while index < lengthForLoop {
                print( "Value of index is: " , index)
                var arrayList = [Any]();
                var k = 0
                while k < 20 && count < arrayTotalLength {
                    print("jhvcnadghscasd" , count)
                    arrayList.append(waypoints[count]);
                    count = count+1;
                    k += 1;
                }
                count = count-1;
                newArray.append(arrayList);
                print("chunk :\(1), count : \(arrayList.count), total count: \(waypoints.count)")
                index = index + 1
            }
            print("array check", newArray)
            
            // call add waypoints to map method here.
            for arrayChuck in newArray {
                addPointsToMap(points: arrayChuck as! [Any])
                print("array chunk count",arrayChuck)
                
            }
        }
        else {
            let originWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: origin[1] as! CLLocationDegrees, longitude: origin[0] as! CLLocationDegrees))
            let destinationWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: destination[1] as! CLLocationDegrees, longitude: destination[0] as! CLLocationDegrees))
            guard origin.count == 2 && destination.count == 2 else { return }
            renderMapWithOriginAndDestination(waypointsArr: [originWaypoint, destinationWaypoint])
        }
        
    }
    
    func addPointsToMap(points: [Any]) {
        var wayTypesPointArray = [Waypoint]()
        print ("addPointsToMap called")
        
        for item in points {
            let itemArray = item as? [Double] ?? []
            print("itemDict" , itemArray)
            let point = Waypoint(coordinate: CLLocationCoordinate2D(latitude: itemArray[1] , longitude: itemArray[0] ))
            point.coordinateAccuracy = 1
            wayTypesPointArray.append(point)
        }
        if wayTypesPointArray.count > 2 {
            drawWayPointsToMap(waypointArray: wayTypesPointArray)
        }
        
    }
    
    func drawWayPointsToMap(waypointArray: [Waypoint]) {
        print("wayTypesPointArray count : ", waypointArray)
        let options = NavigationRouteOptions(waypoints: waypointArray)
        
        Directions.shared.calculate(options) { [weak self] (session, result) in
            guard let strongSelf = self, let parentVC = strongSelf.parentViewController else {
                return
            }
            
            switch result {
            case .failure(let error):
                strongSelf.onError!(["message": error.localizedDescription])
            case .success(let response):
                //                print("responseresponse", response.routes?.last)
                guard let route = response.routes?.first else {
                    return
                }
                
                
                print("route length: ", response.routes?.count ?? "no routes available")
                print("route details: ", route)
                strongSelf.routesFetched.append(route)
                strongSelf.resultsRecieved += 1
                if strongSelf.resultsRecieved == strongSelf.totalChucks {
                    strongSelf.renderMapWithRoutes(routes: strongSelf.routesFetched, options: options)
                }
            }
            
            strongSelf.embedding = true
            strongSelf.embedded = true
        }
    }
    
    func renderMapWithRoutes(routes: [Route], options: RouteOptions) {
        //        let navigationService = MapboxNavigationService(route: route, routeIndex: 0, routeOptions: options, simulating: strongSelf.shouldSimulateRoute ? .always : .never)
        let strongSelf = self
        guard let parentVC = strongSelf.parentViewController else {
            return
        }
        
        var legs = [RouteLeg] ()
        var expectedTimerTravel = TimeInterval()
        var typicalTravelTime = TimeInterval()
        var distance = CLLocationDistance()
        var shapeConcat = LineString([])
        for route in routes {
            legs.append(contentsOf: route.legs)
            shapeConcat.coordinates.append(contentsOf: route.shape?.coordinates ?? [])
            expectedTimerTravel = expectedTimerTravel + route.expectedTravelTime
            typicalTravelTime = typicalTravelTime + (route.typicalTravelTime ?? .zero)
            distance = distance + route.distance
            
        }
        
        let routeConcat = Route(legs: legs, shape: shapeConcat, distance: distance, expectedTravelTime: expectedTimerTravel, typicalTravelTime: typicalTravelTime)
        
        let navigationService = MapboxNavigationService(route: routeConcat, routeIndex: 0, routeOptions: options, simulating: strongSelf.shouldSimulateRoute ? .always : .never)
        
        let navigationOptions = NavigationOptions(navigationService: navigationService)
        
        let vc = NavigationViewController(for: routeConcat, routeIndex: 0, routeOptions: options, navigationOptions: navigationOptions)
        
        vc.showsEndOfRouteFeedback = strongSelf.showsEndOfRouteFeedback
        StatusView.appearance().isHidden = strongSelf.hideStatusView
        
        vc.delegate = strongSelf
        
        parentVC.addChild(vc)
        strongSelf.addSubview(vc.view)
        vc.view.frame = strongSelf.bounds
        vc.didMove(toParent: parentVC)
        strongSelf.navViewController = vc
    }
    
    func renderMapWithOriginAndDestination(waypointsArr: [Waypoint]) {
        
        let options = NavigationRouteOptions(waypoints: waypointsArr)
        Directions.shared.calculate(options) { [weak self] (session, result) in
            guard let strongSelf = self, let parentVC = strongSelf.parentViewController else {
                return
            }
            
            switch result {
            case .failure(let error):
                strongSelf.onError!(["message": error.localizedDescription])
            case .success(let response):
                //                print("responseresponse", response.routes?.last)
                guard let route = response.routes?.first else {
                    return
                }
                
                let navigationService = MapboxNavigationService(route: route, routeIndex: 0, routeOptions: options, simulating: strongSelf.shouldSimulateRoute ? .always : .never)
                
                let navigationOptions = NavigationOptions(navigationService: navigationService)
                
                let vc = NavigationViewController(for: route, routeIndex: 0, routeOptions: options, navigationOptions: navigationOptions)
                
                vc.showsEndOfRouteFeedback = strongSelf.showsEndOfRouteFeedback
                StatusView.appearance().isHidden = strongSelf.hideStatusView
                
                vc.delegate = strongSelf
                
                parentVC.addChild(vc)
                strongSelf.addSubview(vc.view)
                vc.view.frame = strongSelf.bounds
                vc.didMove(toParent: parentVC)
                strongSelf.navViewController = vc
            }
            
            strongSelf.embedding = true
            strongSelf.embedded = true
        }
    }
    
    func navigationViewController(_ navigationViewController: NavigationViewController, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {
        onLocationChange?(["longitude": location.coordinate.longitude, "latitude": location.coordinate.latitude])
        onRouteProgressChange?(["distanceTraveled": progress.distanceTraveled,
                                "durationRemaining": progress.durationRemaining,
                                "fractionTraveled": progress.fractionTraveled,
                                "distanceRemaining": progress.distanceRemaining])
    }
    
    func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        if (!canceled) {
            return;
        }
        
        onCancelNavigation?(["message": ""]);
    }
    
    func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) -> Bool {
        onArrive?(["message": ""]);
        return true;
    }
}
