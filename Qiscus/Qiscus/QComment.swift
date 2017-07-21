//
//  QComment.swift
//  Example
//
//  Created by Ahmad Athaullah on 7/5/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import Foundation
import RealmSwift
import SwiftyJSON

public enum QReplyType:Int{
    case text
    case image
    case video
    case audio
    case document
    case other
}
@objc public enum QCellPosition:Int {
    case single,first,middle,last
}
@objc public enum QCommentType:Int {
    case text
    case image
    case video
    case audio
    case file
    case postback
    case account
    case reply
    case system
}
@objc public enum QCommentStatus:Int{
    case sending
    case sent
    case delivered
    case read
    case failed
}
public class QComment:Object {
    public dynamic var uniqueId: String = ""
    public dynamic var id:Int = 0
    public dynamic var roomId:Int = 0
    public dynamic var beforeId:Int = 0
    public dynamic var text:String = ""
    public dynamic var createdAt: Double = 0
    public dynamic var senderEmail:String = ""
    public dynamic var senderName:String = ""
    public dynamic var statusRaw:Int = QCommentStatus.sending.rawValue
    public dynamic var typeRaw:Int = QCommentType.text.rawValue
    public dynamic var data:String = ""
    public dynamic var cellPosRaw:Int = 0
    
    // MARK : - Ignored Parameters
    var displayImage:UIImage?
    
    // audio variable
    public dynamic var durationLabel = ""
    public dynamic var currentTimeSlider = Float(0)
    public dynamic var seekTimeLabel = "00:00"
    public dynamic var audioIsPlaying = false
    // file variable
    public dynamic var isDownloading = false
    public dynamic var isUploading = false
    public dynamic var progress = CGFloat(0)
    
    
    override public static func ignoredProperties() -> [String] {
        return ["displayImage"]
    }
    
    //MARK : - Getter variable
    public var file:QFile? {
        get{
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            return realm.object(ofType: QFile.self, forPrimaryKey: self.uniqueId)
        }
    }
    public var sender:QUser? {
        get{
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            return realm.object(ofType: QUser.self, forPrimaryKey: self.senderEmail)
        }
    }
    public var cellPos:QCellPosition {
        get{
            return QCellPosition(rawValue: self.cellPosRaw)!
        }
    }
    public var type:QCommentType {
        get{
            return QCommentType(rawValue: self.typeRaw)!
        }
    }
    public var status:QCommentStatus {
        get{
            return QCommentStatus(rawValue: self.statusRaw)!
        }
    }
    public var date: String {
        get {
            let date = Date(timeIntervalSince1970: self.createdAt)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "d MMMM yyyy"
            let dateString = dateFormatter.string(from: date)
            
            return dateString
        }
    }
    public var cellIdentifier:String{
        get{
            var position = "Left"
            if self.senderEmail == QiscusMe.sharedInstance.email {
                position = "Right"
            }
            switch self.type {
            case .system:
                return "cellSystem"
            case .postback,.account:
                return "cellPostbackLeft"
            case .image, .video:
                return "cellMedia\(position)"
            case .audio:
                return "cellAudio\(position)"
            case .file:
                return "cellFile\(position)"
            default:
                return "cellText\(position)"
            }
        }
    }
    public var time: String {
        get {
            let date = Date(timeIntervalSince1970: self.createdAt)
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            let timeString = timeFormatter.string(from: date)
            
            return timeString
        }
    }
    public var textSize:CGSize {
        let textView = UITextView()
        textView.font = Qiscus.style.chatFont
        textView.dataDetectorTypes = .all
        textView.linkTextAttributes = QiscusCommentPresenter().linkTextAttributes
        
        let maxWidth:CGFloat = QiscusUIConfiguration.chatTextMaxWidth
        textView.attributedText = attributedText
        
        var size = textView.sizeThatFits(CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude))
        
        if self.type == .postback && self.data != ""{
            
            let payload = JSON(parseJSON: self.data)
            
            if let buttonsPayload = payload.array {
                let heightAdd = CGFloat(35 * buttonsPayload.count)
                size.height += heightAdd
            }else{
                size.height += 35
            }
        }else if self.type == .account && self.data != ""{
            size.height += 35
        }
        
        return size
    }
    var textAttribute:[String: Any]{
        get{
            if self.type == .system {
                let style = NSMutableParagraphStyle()
                style.alignment = NSTextAlignment.center
                let fontSize = Qiscus.style.chatFont.pointSize
                let systemFont = Qiscus.style.chatFont.withSize(fontSize - 4.0)
                let foregroundColorAttributeName = QiscusColorConfiguration.sharedInstance.systemBalloonTextColor
                
                return [
                    NSForegroundColorAttributeName: foregroundColorAttributeName,
                    NSFontAttributeName: systemFont,
                    NSParagraphStyleAttributeName: style
                ]
            }else{
                var foregroundColorAttributeName = QiscusColorConfiguration.sharedInstance.leftBaloonTextColor
                if self.senderEmail == QiscusMe.sharedInstance.email{
                    foregroundColorAttributeName = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
                }
                return [
                    NSForegroundColorAttributeName: foregroundColorAttributeName,
                    NSFontAttributeName: Qiscus.style.chatFont
                ]
            }
        }
    }
    var attributedText:NSMutableAttributedString {
        get{
            let attributedText = NSMutableAttributedString(string: self.text)
            let allRange = (self.text as NSString).range(of: self.text)
            attributedText.addAttributes(self.textAttribute, range: allRange)
            
            return attributedText
        }
    }
    override open class func primaryKey() -> String {
        return "uniqueId"
    }
    
    public class func comment(withUniqueId uniqueId:String)->QComment?{
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        return realm.object(ofType: QComment.self, forPrimaryKey: uniqueId)
    }
    
    
    fileprivate func isAttachment(text:String) -> Bool {
        var check:Bool = false
        if(text.hasPrefix("[file]")){
            check = true
        }
        return check
    }
    public func getAttachmentURL(message: String) -> String {
        let component1 = message.components(separatedBy: "[file]")
        let component2 = component1.last!.components(separatedBy: "[/file]")
        let mediaUrlString = component2.first?.trimmingCharacters(in: CharacterSet.whitespaces).replacingOccurrences(of: " ", with: "%20")
        return mediaUrlString!
    }
    public func fileName(text:String) ->String{
        let url = getAttachmentURL(message: text)
        var fileName:String? = ""
        
        let remoteURL = url.replacingOccurrences(of: " ", with: "%20")
        let  mediaURL = URL(string: remoteURL)!
        fileName = mediaURL.lastPathComponent.replacingOccurrences(of: "%20", with: "_")
        
        return fileName!
    }
    private func fileExtension(fromURL url:String) -> String{
        var ext = ""
        if url.range(of: ".") != nil{
            let fileNameArr = url.characters.split(separator: ".")
            ext = String(fileNameArr.last!).lowercased()
            if ext.contains("?"){
                let newArr = ext.characters.split(separator: "?")
                ext = String(newArr.first!).lowercased()
            }
        }
        return ext
    }
    public func replyType(message:String)->QReplyType{
        if self.isAttachment(text: message){
            let url = getAttachmentURL(message: message)
            
            switch self.fileExtension(fromURL: url) {
            case "jpg","jpg_","png","png_","gif","gif_":
                return .image
            case "m4a","m4a_","aac","aac_","mp3","mp3_":
                return .audio
            case "mov","mov_","mp4","mp4_":
                return .video
            case "pdf","pdf_","doc","docx","ppt","pptx","xls","xlsx","txt":
                return .document
            default:
                return .other
            }
        }else{
            return .text
        }
    }
    internal func updateCurrentTimeSlider(value:Float){
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        try! realm.write {
            self.currentTimeSlider = value
        }
    }
    internal func updateDurationLabel(text:String){
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        try! realm.write {
            self.durationLabel = text
        }
    }
    internal func updateIsDownloading(downloading:Bool){
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        try! realm.write {
            self.isDownloading = downloading
        }
    }
    internal func updateAudioIsPlaying(playing:Bool){
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        try! realm.write {
            self.audioIsPlaying = playing
        }
    }
    internal func updateSeekTimeLabel(text:String){
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        try! realm.write {
            self.seekTimeLabel = text
        }
    }
}
