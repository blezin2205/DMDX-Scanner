//
//  ViewController.swift
//  scanner_ios_12
//
//  Created by Oleksandr Stepanov on 06.09.2022.
//

import AVFoundation
import UIKit

class ViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    @IBOutlet weak var scanView: UIView!
    @IBOutlet weak var countTextField: UITextField!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var categoryMenuButton: UIButton!
    
    private var lotArray = [Supply]()
    private var categoryArr = ["Alegria", "Siemens"]
    private var categoryTitle = String()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if (captureSession?.isRunning == false) {
            captureSession.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }
    
    func menuAction(action: UIAction) {
        categoryTitle = action.title
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        categoryMenuButton.titleLabel?.numberOfLines = 0
        categoryMenuButton.showsMenuAsPrimaryAction = true
        categoryMenuButton.changesSelectionAsPrimaryAction = true
        
        let arrActions: [UIAction] = categoryArr.map { name -> UIAction in
            return UIAction(title: name, handler: menuAction)
        }
        categoryMenuButton.menu = UIMenu(children: arrActions)
        categoryTitle = categoryArr.first ?? ""
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
        
        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.dataMatrix, .code128]
        } else {
            failed()
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = scanView.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        scanView.layer.addSublayer(previewLayer)
        
        
        captureSession.startRunning()
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func failed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            funcAfterScanBarcode(stringValue, type: metadataObject.type)
        }
        dismiss(animated: true)
    }
    
    
    
    func funcAfterScanBarcode(_ str: String, type: AVMetadataObject.ObjectType) {
        switch type {
        case .code128:
            if categoryTitle == "Siemens" {
                parseForSiemensCategoryCode128(str: str)
            }
            if categoryTitle == "Alegria" {
                parseForAlegriaCategoryCode128(str: str)
            }
        case .dataMatrix:
            if categoryTitle == "Siemens" {
                parseForSiemensCategoryDataMatrix(str: str)
            }
        default:
            break
        }
    }
    
    func parseForAlegriaCategoryCode128(str: String) {
        let smn = str.substring(with: 2..<16)
        let date = str.substring(with: 26..<32)
        let lot = str.suffix(7).description
        
        print("smn = ", smn)
        print("date = ", date)
        print("lot = ", lot)
        writeSuppToDB(smn: smn, lot: lot, expiredDate: date)
    }
    
    func parseForSiemensCategoryCode128(str: String) {
        let str = str.components(separatedBy: ",")
        if str.count == 3 {
            writeSuppToDB(smn: str[0], lot: str[1], expiredDate: str[2])
        } else {
            errorAlert(message: "Error barcode type")
        }
    }
    
    func parseForSiemensCategoryDataMatrix(str: String) {
        let str = str.components(separatedBy: "\u{1D}")
        print(str)
        
        var first: String?
        var second: String?
        var smnSeparate: String?
        
        first = str.first(where: {$0.starts(with: "01")})
        second = str.first(where: {$0.starts(with: "17")})
        smnSeparate = str.first(where: {$0.starts(with: "240")})
        found(first: first, second: second, smnSeparate: smnSeparate)
    }
    
    func found(first: String?, second: String?, smnSeparate: String?) {
        var smn: String?
        var expiredDate: String?
        var lot: String?
        
        if let smnSeparate = smnSeparate {
            smn = smnSeparate.dropFirst(3).description
            print("SMN Separate= ", smn)
        } else if let _smn = second?.dropFirst(11) {
            smn = String(_smn)
            print("SMN = ", smn)
        }
        
        if let _expDate = second?.dropFirst(2).prefix(6) {
            let string = String(_expDate)
            expiredDate = string
            print("Expired Date = ",string)
        }
        
        if let _lot = first?.dropFirst(18) {
            let string = String(_lot)
            lot = string
            print("LOT = ", string)
        }
        
        if let smn = smn, let expiredDate = expiredDate, let lot = lot {
            print("Data = ", smn, " ", expiredDate, " ", lot)
//            checkIfLotAlreadtAddedBySession(smn: smn, lot: lot, expiredDate: expiredDate)
            writeSuppToDB(smn: smn, lot: lot, expiredDate: expiredDate)
        } else {
            let msgError = "Scan data is missed... \n SMN: \(smn ?? "???") \n LOT: \(lot ?? "???") \n expDate: \(expiredDate ?? "???")"
            errorAlert(message: msgError)
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func checkIfLotAlreadtAddedBySession(smn: String, lot: String, expiredDate: String) {
        if let index = lotArray.firstIndex(where: {$0.supplyLot == lot}) {
            let sup = lotArray[index]
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Warning!", message: "\(sup.name) \nLOT: \(lot) \n Товар вже був доданий раніше, додати цей лот?", preferredStyle: UIAlertController.Style.alert)
                alert.setValue(NSAttributedString(string: "ERROR!", attributes: [.foregroundColor : UIColor.orange]), forKey: "attributedTitle")
                alert.addAction(UIAlertAction(title: "Так", style: UIAlertAction.Style.default, handler: { action in
                    self.writeSuppToDB(smn: smn, lot: lot, expiredDate: expiredDate)
                }))
                alert.addAction(UIAlertAction(title: "Ні", style: UIAlertAction.Style.cancel, handler: { action in
                    self.captureSession.startRunning()
                }))
                self.present(alert, animated: true)
            }
        } else {
            writeSuppToDB(smn: smn, lot: lot, expiredDate: expiredDate)
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    private func writeSuppToDB(smn: String, lot: String, expiredDate: String) {
        activityIndicator.startAnimating()
        postRequest(url: "https://dmdxstorage.herokuapp.com/api/supplies_add_from_scan", smn: smn, lot: lot, expiredDate: expiredDate) { result in
            switch result {
                
            case .success(let supp):
                let message = "\(supp.name), \(supp.category)\nLOT: \(supp.supplyLot)\nCount: \(supp.count)"
                self.lotArray.append(supp)
                self.succssAlert(message)
            case .failure(let err):
                print(err)
                self.errorAlert(err)
            }
        }
    }
    
    func errorAlert(_ err: Error? = nil, message: String? = nil) {
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            let alert = UIAlertController(title: "ERROR!", message: err?.localizedDescription ?? message ?? "Error undefined", preferredStyle: UIAlertController.Style.alert)
            alert.setValue(NSAttributedString(string: "ERROR!", attributes: [.foregroundColor : UIColor.red]), forKey: "attributedTitle")
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: { action in
                self.captureSession.startRunning()
            }))
            self.present(alert, animated: true)
        }
    }
    
    func succssAlert(_ message: String) {
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            let alert = UIAlertController(title: "Success", message: message, preferredStyle: UIAlertController.Style.alert)
            alert.setValue(NSAttributedString(string: "SUCCESS", attributes: [.foregroundColor : UIColor.green]), forKey: "attributedTitle")
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: { action in
                self.captureSession.startRunning()
            }))
            self.countTextField.text = "1"
            self.present(alert, animated: true)
        }
    }
    
    func postRequest(url: String, smn: String, lot: String, expiredDate: String, complition: @escaping (Result<Supply, Error>) -> Void) {
        guard let url = URL(string: url) else {return}
        let count = Int(countTextField.text ?? "1") ?? 1
        let userData = ["smn": smn, "supplyLot": lot, "expiredDate": expiredDate, "count": count] as [String : Any]
        var requests = URLRequest(url: url)
        requests.httpMethod = "POST"
        guard let httpBody = try? JSONSerialization.data(withJSONObject: userData, options: []) else {return}
        
        requests.httpBody = httpBody
        requests.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let session = URLSession.shared
        session.dataTask(with: requests) { (data, response, error) in
            guard let response = response as? HTTPURLResponse, let data = data else {return}
            
            guard response.statusCode == 201 else {
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "ERROR!", message: "Status Code = \(response.statusCode)", preferredStyle: UIAlertController.Style.alert)
                    alert.setValue(NSAttributedString(string: "ERROR!", attributes: [.foregroundColor : UIColor.red]), forKey: "attributedTitle")
                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: { action in
                        self.captureSession.startRunning()
                    }))
                    self.present(alert, animated: true)
                }
                return
            }
            
            print(response.statusCode)
            do {
                let decoder = JSONDecoder()
                let supply = try decoder.decode(Supply.self, from: data)
                print(supply)
                complition(.success(supply))
                
            } catch let error {
                print("Error serialization json", error)
                complition(.failure(error))
            }
            }.resume()
        
        
    }
    
}


extension StringProtocol {
    func index<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.lowerBound
    }
    func endIndex<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.upperBound
    }
    func indices<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Index] {
        ranges(of: string, options: options).map(\.lowerBound)
    }
    func ranges<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
            let range = self[startIndex...]
                .range(of: string, options: options) {
                result.append(range)
                startIndex = range.lowerBound < range.upperBound ? range.upperBound :
                    index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
}

struct Supply: Decodable {
    let id: Int
    let dateCreated: String
    let expiredDate: String
    let name: String
    let ref: String?
    let supplyLot: String
    let count: Int
    let category: String
}

struct SuppCategory: Decodable {
    let id: Int
    let name: String
}

extension String {
    func index(from: Int) -> Index {
        return self.index(startIndex, offsetBy: from)
    }

    func substring(from: Int) -> String {
        let fromIndex = index(from: from)
        return String(self[fromIndex...])
    }

    func substring(to: Int) -> String {
        let toIndex = index(from: to)
        return String(self[..<toIndex])
    }

    func substring(with r: Range<Int>) -> String {
        let startIndex = index(from: r.lowerBound)
        let endIndex = index(from: r.upperBound)
        return String(self[startIndex..<endIndex])
    }
}
