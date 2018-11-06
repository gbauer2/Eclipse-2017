//
//  ViewController.swift
//  Stack view
//
//  Created by George Bauer on 9/3/17.
//  Copyright © 2017 GeorgeBauer. All rights reserved.

/*
TODO: ToDo List
 1) Landscape mode
 2) Speed up Play in Settings
 3) propotional timing of images
 4) pinch zoom/pan

*/

import UIKit
import ImageIO
//import MapKit

class ViewController: UIViewController {
    //MARK: ---- @IBOutleta ----
    @IBOutlet weak var imgMain: UIImageView!
    @IBOutlet weak var lblDateTime: UILabel!
    @IBOutlet weak var lblLatiude: UILabel!
    @IBOutlet weak var lblAltitude: UILabel!
    @IBOutlet weak var lblInfo: UILabel!
    @IBOutlet weak var lblMinuteToGo: UITextField!
    @IBOutlet weak var lblExposure: UILabel!
    @IBOutlet weak var btnPlayPause: UIButton!
    @IBOutlet weak var lblVersion: UILabel!

    //MARK: ---- Properties ----
    let fadeSec     = 0.8
    let secTotality = 60 * (60 * 14 + 39) + 23          //Totality started at approx 14:39:23 EDT
    var nextImgNum  = 0
    var gAppVersion = ""
    var gAppBuild   = ""
    var isAnimating = false
    var imageFileArr = [imageFileInfo]()

    typealias imageFileInfo = (name: String, path: String, secEDT: Int, secToNext: Int)

    var timer = Timer()

    //MARK: ---- iOS Overrides & built-in functions ----
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        gAppVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        gAppBuild   = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        lblVersion.text = "Version " + gAppVersion

        //---- Fill an array with the names & paths of jpg files ----
        let filemgr = FileManager.default
        do {
            let resourceKeys : [URLResourceKey] = [ .isDirectoryKey, .nameKey, .pathKey, .typeIdentifierKey, .localizedTypeDescriptionKey]
            let documentsURL = Bundle.main.bundleURL
            guard let enumerator = filemgr.enumerator(at: documentsURL,
                                                includingPropertiesForKeys: resourceKeys,
                                                options: [.skipsHiddenFiles],
                                                errorHandler: { (url, error) -> Bool in
                                                    print("😡directoryEnumerator error at \(url): ", error)
                                                    self.lblMinuteToGo.text = "DirectoryEnumerator error at \(url): "
                                                    self.lblDateTime.text = error.localizedDescription
                                                    return true
            }) else {lblExposure.text = "filemgr.enumerator failed!"; return }

            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                let fileName = resourceValues.name ?? "?"
                let filePath = resourceValues.path ?? "?"
                if fileName.hasSuffix("jpg") && fileName.hasPrefix("se"){
                    // ---- Get dateTimeOriginal here ----
                    let exif = getExif(filePath: filePath)
                    let dateTimeOriginal = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String ?? fileName + " not found!"
                    //print("FileName: \(fileName), dateTimeOriginal: \(dateTimeOriginal)")
                    let dt = decodeDateTime(dateTime: dateTimeOriginal)
                    var secNow = 60 * (60 * dt.hr + dt.min) + dt.sec
                    if dt.day != 21 || dt.mon != 8 || dt.yr != 2017 {secNow = 0}
                    imageFileArr.append((fileName,filePath,secNow,0))
                }//endif
                //print(fileURL.path, resourceValues.isDirectory!, resourceValues.typeIdentifier!, resourceValues.localizedTypeDescription!)
                //                            false                         public.jpeg                         JPEG image
            }//next

            print("😀imageFileArr.count = ", imageFileArr.count)
            imageFileArr.sort(by: { $0.name < $1.name })
            if imageFileArr.count == 0 {
                print("😡No Images found!!")
                lblDateTime.text = "No Images found!!"
                return
            }
            for i in 0..<imageFileArr.count - 1 {
                var secs = imageFileArr[i + 1].secEDT - imageFileArr[i].secEDT
                if secs < 0 || secs > 120 {secs = 120}
                imageFileArr[i].secToNext = secs
            }//next i
            imageFileArr[imageFileArr.count - 1].secToNext = -1
            for item in imageFileArr {
                print("☼\(item.name) \(item.secEDT) \(item.secToNext) ")
            }
        } catch {
            print("😡Error getting image files -> ", error)
        }//catch

    }//end func viewDidLoad

    //------ override viewDidAppear ------
    override func viewDidAppear(_ animated: Bool) {
        if imageFileArr.count > 0 {
            clearLabels()
            DisplayNumberedImage(imgNum: 0, fadeInSec: 2.0)
        }
    }

    //MARK: ---- @IBActions ----
    /*
     Play/Pause buttons
     in playMode:
     When Timer hits:
     1.Display Image(nextImgNum)
     2.nextImgNum += 1
     3.if nextImgNum == 0 Stop
     4.Get Image(nextImgNum); calc elapsed time; set timer
     Next/Prev pressed
     1.playMode = Off; Timer disabled
     2.nextImgNum = nextImgNum +/- 1
     3.Display Image(nextImgNum)
     Play Button Pressed:
     1.playMode On; set Timer to 2sec
     2.nextImgNum += 1
     at Startup:
     1.playMode = Off; Timer disabled
     2.nextImgNum = 0;
     3.Slow Display Image(nextImgNum)
     */

    //------ "Play" Button tapped ------
    @IBAction func btnPlayPausePress(_ sender: Any) {
        if isAnimating {
            StopAnimation()
        } else {
            timer = Timer.scheduledTimer(timeInterval: 0.9, target: self, selector: #selector(ViewController.animate), userInfo: nil, repeats: true)
            btnPlayPause.setTitle("Stop", for: [])
            isAnimating = true
        }
    }//end @IBAction func btnPlayPausePress

    //------ "Next" Button pressed ------
    @IBAction func btnNextPress(_ sender: Any) {
        if isAnimating {StopAnimation()}
        incrNextImgNum()
        DisplayNumberedImage(imgNum: nextImgNum, fadeInSec: fadeSec)
    }//end @IBAction func btnNextPress
    
    //------ "Previous" Button pressed ------
    @IBAction func btnPrevPress(_ sender: Any) {
        if isAnimating {StopAnimation()}
        decrNextImgNum()
        DisplayNumberedImage(imgNum: nextImgNum, fadeInSec: fadeSec)
    }//end @IBAction func btnPrevPress
    
    //MARK: ---- My Functions ----
    func incrNextImgNum() {
        nextImgNum += 1
        if nextImgNum >= imageFileArr.count {nextImgNum = 0}
    }
    func decrNextImgNum() {
        nextImgNum -= 1
        if nextImgNum < 0 {nextImgNum = imageFileArr.count - 1}
    }
    
    func animate() {
        incrNextImgNum()
        DisplayNumberedImage(imgNum: nextImgNum, fadeInSec: fadeSec)
    }//end func Animate
    
    func StopAnimation() {
        timer.invalidate()
        btnPlayPause.setTitle("Play", for: [])
        isAnimating = false
    }

    //--------- Fade-In the new image & Update the text --------
    func DisplayNumberedImage(imgNum: Int, fadeInSec: Double)  {
        clearLabels()
        //let numStr = String(format: "%02d", arguments: [imgNum])
        //let imgName = "Len" + numStr
        if imgNum < 0 || imgNum >= imageFileArr.count {
            lblDateTime.text = "Image#\(imgNum) not in array"
            return
        }
        let imgFullName = imageFileArr[imgNum].name
        let nameParts = imgFullName.components(separatedBy: ".")
        let imgName = nameParts[0]
        let fileType = nameParts[1]
        
        guard let img = UIImage(named: imgFullName) else {
            lblDateTime.text = "\(imgFullName) not found!"
            return
        }
      
        guard let filePath = Bundle.main.path(forResource: imgName, ofType: fileType) else {
            lblDateTime.text = "filePath for \(imgName).\(fileType) not found!"
            return
        }

        let exif = getExif(filePath: filePath)

        let dateTimeOriginal = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String ?? imgFullName + " not found!"

        print("⏰dateTimeOriginal: \(dateTimeOriginal)")
        //let dt = decodeDateTime(dateTime: dateTimeOriginal)
        //let secNow = 60 * (60 * dt.hr + dt.min) + dt.sec
        let secNow = imageFileArr[imgNum].secEDT
        let secToGo = secTotality - secNow
        //let minToGo = (secToGo + 30) / 60
        //var minToGoTxt = ""
        
        switch secToGo {
        case 99...9999999:
            lblMinuteToGo.text = formatMMSS(secs: secToGo) + " minutes to go"
        case 1...99:
            lblMinuteToGo.text = String(secToGo) + " seconds to go"
        case 0:
            lblMinuteToGo.text = "Totality!"
        case -99...(-1):
            lblMinuteToGo.text = String(-secToGo) + " seconds after"
        default:
            lblMinuteToGo.text = "\(-secToGo / 60):\(-secToGo % 60) minutes after"
        }

        if secNow == 0 { lblMinuteToGo.text = "The Sun" }

        var exposureTxt = "|"
        
        var mmLens = "??"
        var ISO = "??"
        var exposureMode = "?"
        var exposureBias = "?"
        var fNumber = "??"
        //let mmLens     = exif["FocalLength"]       as? Int ?? 0
        if let temp      = exif["FocalLength"]       as? Int      { mmLens = String(temp) }
        if let temp      = exif["RecommendedExposureIndex"] as? Int { ISO = String(temp) }
        if let temp      = exif["ExposureMode"]      as? Int      { exposureMode = String(temp) }
        if let temp      = exif["ExposureBiasValue"] as? Int      { exposureBias = String(temp) }
        if let temp      = exif["FNumber"]           as? Double   { fNumber = String(format: "%.1f", temp) }
        let exposureTime = exif["ExposureTime"]      as? Double ?? -1.0
        let shutter = 1.0/exposureTime
        exposureTxt = String(format:"%@mm ISO:%@  f%@ 1/%.0f sec  mode=%@ bias=%@",mmLens, ISO, fNumber, shutter, exposureMode, exposureBias)
        lblExposure.text = exposureTxt
        
        let isValidGPS = exif[kCGImagePropertyGPSStatus as String] as? String ?? "V"
        if isValidGPS == "A" {
            let gpsStat = exif[kCGImagePropertyGPSStatus as String] as? String ?? "?"
            print("\n✿gpsStat = " + gpsStat)
            if gpsStat == "A" {
                var txtLatitude = ""
                var txtLongitude = ""
                if let gpsLat = exif["Latitude"] as? Double {
                    txtLatitude = String(format:"N%7.4f°",gpsLat)
                    txtLatitude = txtLatitude.replacingOccurrences(of: "N ", with: "N0")
                    //print("GPS Latitude: \(gpsLat)")
                }
                if let gpsLon = exif["Longitude"] as? Double {
                    txtLongitude = String(format:"W%8.4f°",gpsLon)
                    txtLongitude = txtLongitude.replacingOccurrences(of: "W ", with: "W0")
                    //print("GPS Longitude: \(gpsLon)")
                }
                lblLatiude.text = txtLatitude + " " + txtLongitude
                
                if var gpsAlt = exif["Altitude"] as? Double {
                    gpsAlt = 3.28084 * gpsAlt
                    lblAltitude.text = String(format:"Alt %5.0f ft",gpsAlt)
                    //print("GPS Altitude: \(gpsAlt)")
                }
                
                if let gps2D3D = exif["MeasureMode"] as? String {
                    lblInfo.text = String("\(gps2D3D)D")
                    if let sats = exif["Satellites"] as? String {
                        lblInfo.text = String("\(gps2D3D)D  \(sats) sats")
                    }
                }
                
            }//endif gpsStatus = "A"
        
        }//endif exif isValidGPS
        
        let nsStr = imgName as NSString
        lblDateTime.text = nsStr.substring(to: 4) + "  " + dateTimeOriginal
        if nsStr.hasPrefix("se87") {
            StopAnimation()
        }
        //imgMain.image = img
        Dissolve(toImage: img, duration: fadeInSec)
        
    }//end DisplayNumberedImage

    func formatMMSS(secs: Int) -> String {
        let sec = abs(secs)
        var secStr = String(sec % 60)
        if secStr.count < 2 { secStr = "0" + secStr }
        return String(secs / 60) + ":" + secStr
    }

    //------ Clear the text - leave placeholder ------
    func clearLabels() {
        lblMinuteToGo.text = "|"
        lblDateTime.text = "|"
        lblLatiude.text = ""
        lblInfo.text = ""
        lblAltitude.text = "no GPS data"
        lblExposure.text = "|"
    }
    
    //------ Do a Dissolve (simultanious fade-out, fade-in) ------
    func Dissolve(toImage: UIImage, duration: Double) {
        UIView.transition(with: self.imgMain,
                          duration: duration,
                          options: .transitionCrossDissolve,
                          animations: {self.imgMain.image = toImage},
                          completion: nil)
    }//end func Dissolve
    
    // ------ from a DateTime string like "2017:08:21 13:22:24", Extract the numbers --------
    func decodeDateTime(dateTime: String) ->(yr: Int, mon: Int, day: Int, hr: Int, min: Int, sec: Int, error: String) {
        let dtArr = dateTime.components(separatedBy: " ")   //split into "Date" and "Time"
        if dtArr.count<2 {return(0,0,0,0,0,0,"No Space separator in \(dateTime)")}
        let dateArr = dtArr[0].components(separatedBy: ":")
        if dateArr.count<3 {return(0,0,0,0,0,0,"Less than 3 numbers in \(dateTime)")}
        let timeArr = dtArr[1].components(separatedBy: ":")
        if timeArr.count<3 {return(0,0,0,0,0,0,"Less than 3 numbers in \(dateTime)")}
        guard let yr  = Int(dateArr[0]) else {return(0,0,0,0,0,0,"Year error in \(dateTime)")}
        guard let mon = Int(dateArr[1]) else {return(yr,0,0,0,0,0,"Month error in \(dateTime)")}
        guard let day = Int(dateArr[2]) else {return(yr,mon,0,0,0,0,"Day error in \(dateTime)")}
        guard let hr  = Int(timeArr[0]) else {return(yr,mon,day,0,0,0,"Hour error in \(dateTime)")}
        guard let min = Int(timeArr[1]) else {return(yr,mon,day,hr,0,0,"Minute error in \(dateTime)")}
        guard let sec = Int(timeArr[2]) else {return(yr,mon,day,hr,min,0,"Second error in \(dateTime)")}
        return (yr,mon,day,hr,min,sec,"")
    }//end func decodeDateTime
   
    // ------ Return the name of an AnyObject var type (to Debug ) ------
    func varType(obj: AnyObject) -> String {
        switch obj {
        case is Double, is Int, is Float:
            return "Numeric"
        case is Bool:
            return "Bool"
        case is String:
            return "String"
        case is Array<String>:
            return "String Array"
        case is Array<Double>:
            return "Numeric Array"
        default:
            return "Unknown Type"
        }//end switch
    }//end func varType
    
//----------------------------------------------------------------------------------------
//-------------------------------- Get Exif Data Class? ----------------------------------
//----------------------------------------------------------------------------------------
    
    //------------------ Get FilePath from fileName,fileType ----------------
    func getFilePath(fileName: String, fileType: String) -> (val: String, error: String) {
        guard let filePath = Bundle.main.path(forResource: fileName, ofType: fileType) else {
            print("\n😡\(fileName).\(fileType) not found!")
            return ("", "\(fileName).\(fileType) not found!")
        }
        return (filePath, "")
    }//end func GetFilePath
    
    //------------------ Get UIImage from filePath -----------------
    func getUiImage(filePath: String) -> (imageUi: UIImage?, error: String) {
        guard let image = UIImage(contentsOfFile: filePath)  else {
            print("😡UIImage not Created")
            return (nil, "UIImage not Created")
        }
        return (image, "")
    }//end func GetUiImage
    
    //------------------ Get ImageProperties from filePath ----------------
    func getImageProperties(filePath: String) -> (imageProperties: Dictionary<String, AnyObject?>?, error: String) {
        
        let url = URL(fileURLWithPath: filePath)
        
        do {
            let data = try Data(contentsOf: url)    //make sure image in this path exists,
            //print ("data = \( data.debugDescription )")
            
            guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
                print ("😡imageSource could not be created for \(filePath)")
                return (nil, "imageSource could not be created for \(filePath)")
            }
            //print ("ImageSource = \( imageSource.debugDescription )")
            
            guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? Dictionary<String, AnyObject> else {
                return (nil, "Could not get imageProperties")
            }
            
            return (imageProperties, "")
            
        }//end do
        catch {
            print ("\n😡data = try Data(contentsOf: url) failed!")
            return (nil, "data = try Data(contentsOf: url) failed!")
        }//end catch
        
    }//end func getJpegData
    
    //----------------------- Get Exif Dictionary ---------------------
    func getExif(filePath: String) -> Dictionary<String, AnyObject> {
        var nilDict = ["isValidGPS": false as AnyObject, "error": "Unknown Error" as AnyObject]
        let imagePropertiesTuple = getImageProperties(filePath: filePath)
        if imagePropertiesTuple.error != "" {
            nilDict["error"] = imagePropertiesTuple.error as AnyObject
            return nilDict
        }
        
        guard var exifDict = imagePropertiesTuple.imageProperties?[kCGImagePropertyExifDictionary as String] as? Dictionary<String, AnyObject> else {
            nilDict["error"] = "Could not create exifDict" as AnyObject
            return nilDict
        }
        guard let gpsDict = imagePropertiesTuple.imageProperties?[kCGImagePropertyGPSDictionary as String] as? Dictionary<String, AnyObject> else {
            exifDict["error"] = "Could not get gpsDict" as AnyObject
            return exifDict
        }
        
        //exifDict.forEach {(key, val) in print(key, val)}  // print exif data
        
        gpsDict.forEach { (key,val) in exifDict[key] = val }        // Add GPS Dictionary to EXIF Dictionary
        // in Swift4: exifDict.merge(gpsDict)
        exifDict["error"] = "" as AnyObject
        
        /*
        print("\n------ Exif Data (including GPS -----")
        exifDict.forEach {
            (key, val) in print("\"\(key)\" (\(varType(obj: val)))  ", val )
        }   // print exif data
        print("-------------------------------------\n")
        */
        return exifDict
    }//end func getExif
//----------------------------------------------------------------------------------------
//-------------------------------- End Exif Data Class? ----------------------------------
//----------------------------------------------------------------------------------------
    
}//end Class

//MARK: Exif Data
/*
 ExifVersion ( 2, 3 )
 ISOSpeedRatings ( 200 )
 RecommendedExposureIndex 200
 FNumber 22
 ExposureTime 0.00025
 ExposureMode 1
 ExposureProgram 1
 ExposureBiasValue 0
 WhiteBalance 0
 FocalLength 312
 DateTimeOriginal 2017:08:21 13:22:24
 DateTimeDigitized 2017:08:21 13:22:24

 LensSpecification ( 100, 400, 0, 0 )
 LensModel EF100-400mm f/4.5-5.6L IS II USM
 SceneCaptureType 0
 MeteringMode 5

 PixelYDimension 1401
 CustomRendered 0
 SensitivityType 2
 SubsecTimeDigitized 00
 Flash 16
 ApertureValue 9
 FocalPlaneXResolution 3810.58495821727
 FlashPixVersion ( 1, 0 )
 SubsecTimeOriginal 00
 ColorSpace 1
 ComponentsConfiguration ( 1, 2, 3, 0 )
 SubsecTime 390
 ShutterSpeedValue 12
 PixelXDimension 1401
 FocalPlaneResolutionUnit 2
 FocalPlaneYResolution 3815.899581589958
 BodySerialNumber 352051000769
 LensSerialNumber 3270000390

 ---- No Valid GPS Data ----
 GPSVersion ( 2, 3, 0, 0 )
 Status V
 MapDatum WGS-84

 ----- Valid GPS Data -----
 GPSVersion ( 2, 3, 0, 0 )
 Status A
 Latitude 34.24683
 LatitudeRef N
 Longitude 82.15332166666667
 LongitudeRef W
 Altitude 188.2
 AltitudeRef 0
 MeasureMode 3
 DOP 5.2
 TimeStamp 17:27:09
 Satellites 12
 DateStamp 2017:08:21
 MapDatum WGS-84
--------------------------
 */
