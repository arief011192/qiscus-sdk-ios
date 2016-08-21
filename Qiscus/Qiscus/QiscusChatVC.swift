//
//  QiscusChatVC.swift
//  Example
//
//  Created by Ahmad Athaullah on 8/18/16.
//  Copyright © 2016 Ahmad Athaullah. All rights reserved.
//

import UIKit
//import Qiscus
import SJProgressHUD
import MobileCoreServices
import AVFoundation
import Photos

public class QiscusChatVC: UIViewController, ChatInputTextDelegate, QCommentDelegate/*, MWPhotoBrowserDelegate*/, UIImagePickerControllerDelegate, UITableViewDelegate, UITableViewDataSource,UINavigationControllerDelegate, UIDocumentPickerDelegate/*, QVCChatClientDelegate*/ {
    
    static let sharedInstance = QiscusChatVC()
    
    // MARK: - IBOutlet Properties
    @IBOutlet weak var inputBar: UIView!
    @IBOutlet weak var inputText: ChatInputText!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var welcomeView: UIView!
    @IBOutlet weak var welcomeText: UILabel!
    @IBOutlet weak var welcomeSubtitle: UILabel!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var galeryButton: UIButton!
    @IBOutlet weak var archievedNotifView: UIView!
    @IBOutlet weak var archievedNotifLabel: UILabel!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var documentButton: UIButton!
    @IBOutlet weak var unlockButton: UIButton!
    
    // MARK: - Constrain
    @IBOutlet weak var minInputHeight: NSLayoutConstraint!
    @IBOutlet weak var welcomeViewHeight: NSLayoutConstraint!
    @IBOutlet weak var archievedNotifTop: NSLayoutConstraint!
    @IBOutlet weak var inputBarBottomMargin: NSLayoutConstraint!
    @IBOutlet weak var tableViewBottomConstrain: NSLayoutConstraint!
    
    
    // MARK: - View Attributes
    var defaultViewHeight:CGFloat = 0
    
    // MARK: - Data Properties
    var hasMoreComment = true
    var loadMoreControl = UIRefreshControl()
    var commentClient = QiscusCommentClient.sharedInstance
    var topicId = QiscusUIConfiguration.sharedInstance.topicId
    //var room:QiscusRoom = QiscusRoom()
    var consultantId: Int = 0
    var consultantRate:Int = 0
    var comment = [[QiscusComment]]()
    var archived:Bool = QiscusUIConfiguration.sharedInstance.readOnly
    var rowHeight:[NSIndexPath: CGFloat] = [NSIndexPath: CGFloat]()
    var firstLoad = true
    
    var topColor = UIColor(red: 8/255.0, green: 153/255.0, blue: 140/255.0, alpha: 1.0)
    var bottomColor = UIColor(red: 23/255.0, green: 177/255.0, blue: 149/255.0, alpha: 1)
    var tintColor = UIColor.whiteColor()
    var syncTimer:NSTimer?
    
    //MARK: - external action
    public var unlockAction:(()->Void) = {}
    public var cellDelegate:QiscusChatCellDelegate?
    
    var bundle:NSBundle {
        get{
            return NSBundle.init(forClass: Qiscus.classForCoder())
        }
    }
    var sendOnImage:UIImage?{
        get{
            return UIImage(named: "ic_send_on", inBundle: self.bundle, compatibleWithTraitCollection: nil)?.localizedImage()
        }
    }
    var sendOffImage:UIImage?{
        get{
            return UIImage(named: "ic_send_off", inBundle: self.bundle, compatibleWithTraitCollection: nil)?.localizedImage()
        }
    }
    var nextIndexPath:NSIndexPath{
        get{
            let indexPath = QiscusHelper.getNextIndexPathIn(groupComment:self.comment)
            return NSIndexPath(forRow: indexPath.row, inSection: indexPath.section)
        }
    }
    var isLastRowVisible: Bool {
        get{
            if self.comment.count > 0{
                let lastSection = self.comment.count - 1
                let lastRow = self.comment[lastSection].count - 1
                if let indexPaths = self.tableView.indexPathsForVisibleRows {
                    for indexPath in indexPaths {
                        if indexPath.section == lastSection && indexPath.row == lastRow{
                            return true
                        }
                    }
                }
            }
            return false
        }
    }
    
    var lastVisibleRow:NSIndexPath?{
        get{
            if self.comment.count > 0{
                if let indexPaths = self.tableView.indexPathsForVisibleRows {
                    return indexPaths.last!
                }
            }
            return nil
        }
    }
    var UTIs:[String]{
        get{
            return ["public.jpeg", "public.png"/*,"com.compuserve.gif"*/,"public.text", "public.archive", "com.microsoft.word.doc", "com.microsoft.excel.xls", "com.microsoft.powerpoint.​ppt", "com.adobe.pdf"/*,"public.mpeg-4" */]
        }
    }
    
    private init() {
        super.init(nibName: "QiscusChatVC", bundle: Qiscus.bundle)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Lifecycle
    override public func viewDidLoad() {
        super.viewDidLoad()
        print ("topicId: \(topicId)")
        /*        IQKeyboardManager.sharedManager().enable = false */
        commentClient.commentDelegate = self
    }
    override public func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        print("invalidate sync timer")
        self.syncTimer?.invalidate()
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIKeyboardWillHideNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIKeyboardWillChangeFrameNotification, object: nil)
    }
    override public func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        firstLoad = true
        self.syncTimer = NSTimer.scheduledTimerWithTimeInterval(5, target: self, selector: #selector(QiscusChatVC.syncData), userInfo: nil, repeats: true)
        setupPage()
        loadData()
    }
    
    // MARK: - Memory Warning
    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Setup UI
    func setupPage(){
        if archived {
            //inputBar.hidden = true
            //tableViewBottomConstrain.constant = 28
            self.archievedNotifLabel.text = QiscusUIConfiguration.sharedInstance.readOnlyText
        }else{
            archievedNotifView.hidden = true
            self.archievedNotifTop.constant = 65
        }
        if Qiscus.sharedInstance.iCloudUpload {
            self.documentButton.hidden = false
        }else{
            self.documentButton.hidden = true
        }
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.archievedNotifView.backgroundColor = QiscusUIConfiguration.sharedInstance.lockViewBgColor
        self.archievedNotifLabel.textColor = QiscusUIConfiguration.sharedInstance.lockViewTintColor
        let unlockImage = Qiscus.image(named: "ic_open_archived")?.imageWithRenderingMode(.AlwaysTemplate)
        self.unlockButton.setBackgroundImage(unlockImage, forState: .Normal)
        self.unlockButton.tintColor = QiscusUIConfiguration.sharedInstance.lockViewTintColor
        
        let cellTextBundles = NSBundle.init(forClass: ChatCellText.classForCoder())
        let cellMediaBundles = NSBundle.init(forClass: ChatCellMedia.classForCoder())
        let cellDocsBundles = NSBundle.init(forClass: ChatCellDocs.classForCoder())
        
        self.tableView.registerNib(UINib(nibName: "ChatCellText",bundle: cellTextBundles), forCellReuseIdentifier: "cellText")
        self.tableView.registerNib(UINib(nibName: "ChatCellMedia",bundle: cellMediaBundles), forCellReuseIdentifier: "cellMedia")
        self.tableView.registerNib(UINib(nibName: "ChatCellDocs",bundle: cellDocsBundles), forCellReuseIdentifier: "cellDocs")
        
        //navigation Setup
        self.navigationItem.setTitleWithSubtitle(title: QiscusUIConfiguration.sharedInstance.chatTitle, subtitle:QiscusUIConfiguration.sharedInstance.chatSubtitle)
        //
        if !Qiscus.sharedInstance.isPushed{
            self.navigationController?.navigationBar.verticalGradientColor(topColor, bottomColor: bottomColor)
            self.navigationController?.navigationBar.tintColor = tintColor
        }
        
        let backButton = QiscusChatVC.backButton(self, action: #selector(QiscusChatVC.goBack(_:)))
        self.navigationItem.setHidesBackButton(true, animated: false)
        self.navigationItem.leftBarButtonItem = backButton
        
        // loadMoreControl
        self.loadMoreControl.addTarget(self, action: #selector(QiscusChatVC.loadMore), forControlEvents: UIControlEvents.ValueChanged)
        self.tableView.addSubview(self.loadMoreControl)
        
        // button setup
        sendButton.setBackgroundImage(self.sendOffImage, forState: .Disabled)
        sendButton.setBackgroundImage(self.sendOnImage, forState: .Normal)
        
        if inputText.value == "" {
            sendButton.enabled = false
        }else{
            sendButton.enabled = true
        }
        sendButton.addTarget(self, action: #selector(QiscusChatVC.sendMessage), forControlEvents: .TouchUpInside)
        
        //welcomeView Setup
        self.unlockButton.addTarget(self, action: #selector(QiscusChatVC.confirmUnlockChat), forControlEvents: .TouchUpInside)
        
        self.welcomeViewHeight.constant = (self.tableView.frame.height - 210) / 2
        self.welcomeText.text = QiscusUIConfiguration.sharedInstance.emptyTitle
        self.welcomeSubtitle.text = QiscusUIConfiguration.sharedInstance.emptyMessage
        
        self.inputText.textContainerInset = UIEdgeInsetsZero
        self.inputText.placeholder = QiscusUIConfiguration.sharedInstance.textPlaceholder
        self.inputText.chatInputDelegate = self
        self.defaultViewHeight = self.view.frame.height - (self.navigationController?.navigationBar.frame.height)! - QiscusHelper.statusBarSize().height
        
        // upload button setup
        self.galeryButton.addTarget(self, action: #selector(self.uploadImage), forControlEvents: .TouchUpInside)
        self.cameraButton.addTarget(self, action: #selector(QiscusChatVC.uploadFromCamera), forControlEvents: .TouchUpInside)
        self.documentButton.addTarget(self, action: #selector(QiscusChatVC.iCloudOpen), forControlEvents: .TouchUpInside)
        
        // Keyboard stuff.
        let center: NSNotificationCenter = NSNotificationCenter.defaultCenter()
        center.addObserver(self, selector: #selector(QiscusChatVC.keyboardWillHide(_:)), name: UIKeyboardWillHideNotification, object: nil)
        center.addObserver(self, selector: #selector(QiscusChatVC.keyboardChange(_:)), name: UIKeyboardWillChangeFrameNotification, object: nil)
        
        self.hideKeyboardWhenTappedAround()
    }
    func showPhotoAccessAlert(){
        dispatch_async(dispatch_get_main_queue(), {
            let title = QiscusUIConfiguration.sharedInstance.galeryAccessAlertTitle
            let text = QiscusUIConfiguration.sharedInstance.galeryAccessAlertText
            let cancelTxt = QiscusUIConfiguration.sharedInstance.alertCancelText
            let settingTxt = QiscusUIConfiguration.sharedInstance.alertSettingText
            let alertview = QiscusAlert().show(self, title: title, text: text, buttonText: settingTxt, cancelButtonText: cancelTxt, color: UIColor.whiteColor(), iconImage: nil, inputText: nil)
            alertview.addAction(self.goToIPhoneSetting)
            alertview.addCancelAction({})
        })
    }
    func showCameraAccessAlert(){
        dispatch_async(dispatch_get_main_queue(), {
            let title = QiscusUIConfiguration.sharedInstance.galeryAccessAlertTitle
            let text = QiscusUIConfiguration.sharedInstance.galeryAccessAlertText
            let cancelTxt = QiscusUIConfiguration.sharedInstance.alertCancelText
            let settingTxt = QiscusUIConfiguration.sharedInstance.alertSettingText
            let alertview = QiscusAlert().show(self, title: title, text: text, buttonText: settingTxt, cancelButtonText: cancelTxt, color: UIColor.whiteColor(), iconImage: nil, inputText: nil)
            alertview.addAction(self.goToIPhoneSetting)
            alertview.addCancelAction({})
        })
    }
    func goToGaleryPicker(){
        dispatch_async(dispatch_get_main_queue(), {
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.allowsEditing = false
//            if !Qiscus.sharedInstance.isPushed {
//                picker.navigationBar.verticalGradientColor(self.topColor, bottomColor: QiscusUIConfiguration.sharedInstance.gradientColor)
//                picker.navigationBar.tintColor = UIColor.whiteColor()
//            }
            picker.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
            picker.mediaTypes = [/*kUTTypeMovie as String,*/ kUTTypeImage as String]
            self.navigationController?.pushViewController(picker, animated: true)
        })
    }
    
    // MARK: - Keyboard Methode
    func keyboardWillHide(notification: NSNotification){
        let info: NSDictionary = notification.userInfo!
        
        let animateDuration = info[UIKeyboardAnimationDurationUserInfoKey] as! Double
        let goToRow = self.lastVisibleRow
        
        UIView.animateWithDuration(animateDuration, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: {
            self.inputBarBottomMargin.constant = 0
            self.view.layoutIfNeeded()
            if goToRow != nil {
                self.scrollToIndexPath(goToRow!, position: .Bottom, animated: true, delayed:  false)
            }
            }, completion: nil)
    }
    func keyboardChange(notification: NSNotification){
        let info:NSDictionary = notification.userInfo!
        let keyboardSize = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
        
        let keyboardHeight: CGFloat = keyboardSize.height
        let animateDuration = info[UIKeyboardAnimationDurationUserInfoKey] as! Double
        
        let goToRow = self.lastVisibleRow
        
        UIView.animateWithDuration(animateDuration, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: {
            self.inputBarBottomMargin.constant = 0 - keyboardHeight
            self.view.layoutIfNeeded()
            if goToRow != nil {
                self.scrollToIndexPath(goToRow!, position: .Bottom, animated: true, delayed:  false)
            }
            }, completion: nil)
        
    }
    
    // MARK: - ChatInputTextDelegate Delegate
    func chatInputTextDidChange(chatInput input: ChatInputText, height: CGFloat) {
        self.minInputHeight.constant = height
        input.layoutIfNeeded()
    }
    func valueChanged(value value:String){
        if value == "" {
            sendButton.enabled = false
            sendButton.setBackgroundImage(self.sendOffImage, forState: .Normal)
        }else{
            sendButton.enabled = true
            sendButton.setBackgroundImage(self.sendOnImage, forState: .Normal)
        }
    }
    // MARK: - Table View DataSource
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int{
        return self.comment[section].count
    }
    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell{
        let comment = self.comment[indexPath.section][indexPath.row]
        var cellPosition: CellPosition = CellPosition.Left
        print("commentType: \(comment.commentType)")
        if comment.commentSenderEmail == QiscusConfig.sharedInstance.USER_EMAIL{
            cellPosition = CellPosition.Right
        }
        
        var first = false
        if indexPath.row == 0 {
            first = true
        }else{
            let commentBefore = self.comment[indexPath.section][indexPath.row - 1]
            if (commentBefore.commentSenderEmail as String) != (comment.commentSenderEmail as String){
                first = true
            }
        }
        if comment.commentType == QiscusCommentType.Text {
            let cell = tableView.dequeueReusableCellWithIdentifier("cellText", forIndexPath: indexPath) as! ChatCellText
            
            cell.setupCell(comment,first: first, position: cellPosition)
            return cell
        }else{
            let file = QiscusFile.getCommentFile(comment.commentFileId)
            if file?.fileType == QFileType.Media{
                let cell = tableView.dequeueReusableCellWithIdentifier("cellMedia", forIndexPath: indexPath) as! ChatCellMedia
                cell.setupCell(comment, first: first, position: cellPosition)
                
                if file!.isLocalFileExist(){
                    cell.tapRecognizer = ChatTapRecognizer(target:self, action:#selector(QiscusChatVC.tapMediaDisplay(_:)))
                    cell.tapRecognizer?.fileName = (file?.fileName)!
                    cell.tapRecognizer?.fileType = .Media
                    cell.tapRecognizer?.fileURL = (file?.fileURL)!
                    cell.tapRecognizer?.fileLocalPath = (file?.fileLocalPath)!
                    cell.mediaDisplay.addGestureRecognizer(cell.tapRecognizer!)
                }
                return cell
            }else{
                let cell = tableView.dequeueReusableCellWithIdentifier("cellDocs", forIndexPath: indexPath) as! ChatCellDocs
                cell.setupCell(comment, first: first, position: cellPosition)
                
                if !file!.isUploading{
                    cell.tapRecognizer = ChatTapRecognizer(target:self, action:#selector(QiscusChatVC.tapChatFile(_:)))
                    cell.tapRecognizer?.fileURL = file!.fileURL
                    cell.tapRecognizer?.fileName = file!.fileName
                    cell.fileContainer.addGestureRecognizer(cell.tapRecognizer!)
                }
                return cell
            }
        }
        
    }
    public func numberOfSectionsInTableView(tableView: UITableView) -> Int{
        return self.comment.count
    }
    
    // MARK: - TableView Delegate
    public func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat{
        return 30
    }
    public func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat{
        var height:CGFloat = 50
        if self.comment.count > 0 {
            let comment = self.comment[indexPath.section][indexPath.row]
            
            if comment.commentType == QiscusCommentType.Text {
                height = ChatCellText.calculateRowHeightForComment(comment: comment)
            }else{
                let file = QiscusFile.getCommentFile(comment.commentFileId)
                
                if file?.fileType == QFileType.Media {
                    height = 170
                }else{
                    height = 70
                }
            }
        }
        return height
    }
    public func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?{
        let comment = self.comment[section][0]
        
        var date:String = ""
        
        if comment.commentDate == QiscusHelper.thisDateString {
            date = QiscusUIConfiguration.sharedInstance.todayText
        }else{
            date = comment.commentDate
        }
        
        let view = UIView(frame: CGRectMake(0,10,QiscusHelper.screenWidth(),20))
        view.backgroundColor = UIColor.whiteColor()
        
        let dateLabel = UILabel(frame: view.frame)
        dateLabel.textAlignment = .Center
        dateLabel.text = date
        dateLabel.font = UIFont.boldSystemFontOfSize(12)
        dateLabel.textColor = UIColor(red: 63/255.0, green: 63/255.0, blue: 63/255.0, alpha: 1)
        view.addSubview(dateLabel)
        
        return view
    }
    
    func scrollToBottom(animated:Bool = false){
        if self.comment.count > 0{
            let section = self.comment.count - 1
            let row = self.comment[section].count - 1
            let bottomIndexPath = NSIndexPath(forRow: row, inSection: section)
            scrollToIndexPath(bottomIndexPath, position: .Bottom, animated: animated)
        }
    }
    func scrollToIndexPath(indexPath:NSIndexPath, position: UITableViewScrollPosition, animated:Bool, delayed:Bool = true){
        
        if !delayed {
            self.tableView?.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.Bottom, animated: false)
        }else{
            let delay = 0.1 * Double(NSEC_PER_SEC)
            let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
            dispatch_after(time, dispatch_get_main_queue(), {
                if self.comment.count > 0 {
                self.tableView?.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.Bottom,
                    animated: false)
                }
            })
        }
    }
    // MARK: - Navigation Action
    func rightLeftButtonAction(sender: AnyObject) {
    }
    func righRightButtonAction(sender: AnyObject) {
    }
    func goBack(sender: AnyObject) {
        if Qiscus.sharedInstance.isPushed {
            self.navigationController?.popViewControllerAnimated(true)
        }else{
            self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    // MARK: - Load DataSource
    func loadData(){
        SJProgressHUD.showWaiting("Load Data ...", autoRemove: false)
        self.comment = QiscusComment.groupAllCommentByDate(self.topicId,limit:20,firstLoad: true)
        print("self.comment:  \(self.comment)")
        
        if self.comment.count > 0 {
            self.tableView.reloadData()
            scrollToBottom()
            self.welcomeView.hidden = true
            commentClient.syncMessage(self.topicId)
            SJProgressHUD.dismiss()
        }else{
            self.welcomeView.hidden = false
            commentClient.getListComment(topicId: self.topicId, commentId: 0, triggerDelegate: true)
        }
    }
    func syncData(){
        //print("syncData ..... ")
        commentClient.syncMessage(self.topicId)
    }
    // MARK: - Qiscus Comment Delegate
    public func didSuccesPostComment(comment:QiscusComment){
        if comment.commentTopicId == self.topicId {
            let indexPathData = QiscusHelper.getIndexPathOfComment(comment: comment, inGroupedComment: self.comment)
            let indexPath = NSIndexPath(forRow: indexPathData.row, inSection: indexPathData.section)
            dispatch_async(dispatch_get_main_queue()) {
                self.comment[indexPathData.section][indexPathData.row] = comment
                self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
            }
        }
    }
    public func didFailedPostComment(comment:QiscusComment){
        if comment.commentTopicId == self.topicId {
            let indexPathData = QiscusHelper.getIndexPathOfComment(comment: comment, inGroupedComment: self.comment)
            let indexPath = NSIndexPath(forRow: indexPathData.row, inSection: indexPathData.section)
            dispatch_async(dispatch_get_main_queue()) {
                self.comment[indexPathData.section][indexPathData.row] = comment
                self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
            }
        }
        
    }
    public func downloadingMedia(comment:QiscusComment){
        let file = QiscusFile.getCommentFileWithComment(comment)!
        let indexPathData = QiscusHelper.getIndexPathOfComment(comment: comment, inGroupedComment: self.comment)
        if file.fileType == .Media {
            let indexPath = NSIndexPath(forRow: indexPathData.row, inSection: indexPathData.section)
            if let cell = self.tableView.cellForRowAtIndexPath(indexPath) as? ChatCellMedia{
                let downloadProgress:Int = Int(file.downloadProgress * 100)
                if file.downloadProgress > 0 {
                    cell.downloadButton.hidden = true
                    cell.progressLabel.text = "\(downloadProgress) %"
                    cell.progressLabel.hidden = false
                    cell.progressContainer.hidden = false
                    cell.progressView.hidden = false
                    
                    let newHeight = file.downloadProgress * cell.maxProgressHeight
                    cell.progressHeight.constant = newHeight
                    cell.progressView.layoutIfNeeded()
                }
            }
        }
    }
    public func didDownloadMedia(comment: QiscusComment){
        let file = QiscusFile.getCommentFileWithComment(comment)!
        let indexPathData = QiscusHelper.getIndexPathOfComment(comment: comment, inGroupedComment: self.comment)
        if file.fileType == .Media {
            let indexPath = NSIndexPath(forRow: indexPathData.row, inSection: indexPathData.section)
            if let cell = self.tableView.cellForRowAtIndexPath(indexPath) as? ChatCellMedia{
                cell.downloadButton.hidden = true
                cell.progressLabel.hidden = true
                cell.mediaDisplay.loadAsync("file://\(file.fileThumbPath)")
                cell.fileNameLabel.hidden = true
                cell.fileIcon.hidden = true
                if cell.tapRecognizer != nil {
                    cell.mediaDisplay.removeGestureRecognizer(cell.tapRecognizer!)
                }
                cell.tapRecognizer = ChatTapRecognizer(target:self, action:#selector(QiscusChatVC.tapMediaDisplay(_:)))
                cell.tapRecognizer?.fileType = file.fileType
                cell.tapRecognizer?.fileName = file.fileName
                cell.tapRecognizer?.fileLocalPath = file.fileLocalPath
                cell.tapRecognizer?.fileURL = file.fileURL
                cell.progressContainer.hidden = true
                cell.progressView.hidden = true
                cell.mediaDisplay.addGestureRecognizer(cell.tapRecognizer!)
            }
        }
    }
    public func didUploadFile(comment:QiscusComment){
        let file = QiscusFile.getCommentFileWithComment(comment)!
        let indexPathData = QiscusHelper.getIndexPathOfComment(comment: comment, inGroupedComment: self.comment)
        if file.fileType == .Media {
            let indexPath = NSIndexPath(forRow: indexPathData.row, inSection: indexPathData.section)
            if let cell = self.tableView.cellForRowAtIndexPath(indexPath) as? ChatCellMedia {
                cell.downloadButton.hidden = true
                cell.progressLabel.hidden = true
                cell.progressContainer.hidden = true
                cell.progressView.hidden = true
                //cell.mediaDisplay.loadAsync("file://\(file.fileThumbPath)")
                cell.fileNameLabel.hidden = true
                cell.fileIcon.hidden = true
                if cell.tapRecognizer != nil {
                    cell.mediaDisplay.removeGestureRecognizer(cell.tapRecognizer!)
                }
                cell.tapRecognizer = ChatTapRecognizer(target:self, action:#selector(QiscusChatVC.tapMediaDisplay(_:)))
                cell.tapRecognizer?.fileType = file.fileType
                cell.tapRecognizer?.fileName = file.fileName
                cell.tapRecognizer?.fileLocalPath = file.fileLocalPath
                cell.tapRecognizer?.fileURL = file.fileURL
                cell.mediaDisplay.addGestureRecognizer(cell.tapRecognizer!)
            }
        }else{
            let indexPath = NSIndexPath(forRow: indexPathData.row, inSection: indexPathData.section)
            if let cell = self.tableView.cellForRowAtIndexPath(indexPath) as? ChatCellDocs {
                if cell.tapRecognizer != nil {
                    cell.fileContainer.removeGestureRecognizer(cell.tapRecognizer!)
                }
                cell.tapRecognizer = ChatTapRecognizer(target:self, action:#selector(QiscusChatVC.tapChatFile(_:)))
                cell.tapRecognizer?.fileURL = file.fileURL
                
                cell.fileContainer.addGestureRecognizer(cell.tapRecognizer!)
            }
        }
    }
    public func uploadingFile(comment:QiscusComment){
        let file = QiscusFile.getCommentFileWithComment(comment)!
        let indexPathData = QiscusHelper.getIndexPathOfComment(comment: comment, inGroupedComment: self.comment)
        let indexPath = NSIndexPath(forRow: indexPathData.row, inSection: indexPathData.section)
        if file.fileType == .Media {
            if let cell = self.tableView.cellForRowAtIndexPath(indexPath) as? ChatCellMedia {
                let downloadProgress:Int = Int(file.uploadProgress * 100)
                if file.uploadProgress > 0 {
                    cell.downloadButton.hidden = true
                    cell.progressLabel.text = "\(downloadProgress) %"
                    cell.progressLabel.hidden = false
                    cell.progressContainer.hidden = false
                    cell.progressView.hidden = false
                    
                    let newHeight = file.uploadProgress * cell.maxProgressHeight
                    cell.progressHeight.constant = newHeight
                    cell.progressView.layoutIfNeeded()
                }
            }
        }else{
            if let cell = self.tableView.cellForRowAtIndexPath(indexPath) as? ChatCellDocs {
                if file.uploadProgress > 0 {
                    let uploadProgres = Int(file.uploadProgress * 100)
                    let uploading = QiscusUIConfiguration.sharedInstance.uploadingText
                    
                    cell.dateLabel.text = "\(uploading) \(ChatCellDocs.getFormattedStringFromInt(uploadProgres)) %"
                }
            }
        }
    }
    public func didFailedUploadFile(comment:QiscusComment){
        
    }
    public func didSuccessPostFile(comment:QiscusComment){
        
    }
    public func didFailedPostFile(comment:QiscusComment){
        
    }
    public func didFinishLoadMore(){
        self.loadMoreControl.endRefreshing()
    }
    public func finishedLoadFromAPI(topicId: Int){
        SJProgressHUD.dismiss()
    }
    public func didFailedLoadDataFromAPI(error: String){
        SJProgressHUD.dismiss()
    }
    public func gotNewComment(comments:[QiscusComment]){
        var refresh = false
        if self.comment.count == 0 {
            refresh = true
        }
        print("comments: \(comments)")
        var indexPaths = [NSIndexPath]()
        var indexSets = [NSIndexSet]()
        var needScroolToBottom = false
        //update data first
        if firstLoad{
            needScroolToBottom = true
            firstLoad = false
        }
        if isLastRowVisible && !needScroolToBottom{
            needScroolToBottom = true
        }
        if comments.count == 1 && !needScroolToBottom{
            let firstComment = comments[0]
            if firstComment.commentSenderEmail == QiscusConfig.sharedInstance.USER_EMAIL{
                needScroolToBottom = true
            }
        }
        var i = 0
        for singleComment in comments{
            if singleComment.commentTopicId == self.topicId {
                let indexPathData = QiscusHelper.properIndexPathOf(comment: singleComment, inGroupedComment: self.comment)
                
                let indexPath = NSIndexPath(forRow: indexPathData.row, inSection: indexPathData.section)
                let indexSet = NSIndexSet(index: indexPathData.section)
                
                if indexPathData.newGroup {
                    var newCommentGroup = [QiscusComment]()
                    newCommentGroup.append(singleComment)
                    self.comment.insert(newCommentGroup, atIndex: indexPathData.section)
                    indexSets.append(indexSet)
                    indexPaths.append(indexPath)
                }else{
                    self.comment[indexPathData.section].insert(singleComment, atIndex: indexPathData.row)
                    indexPaths.append(indexPath)
                }
            }
            i += 1
        }
        self.welcomeView.hidden = true
        
        if !refresh {
        self.tableView.beginUpdates()
            for indexSet in indexSets{
                self.tableView.insertSections(indexSet, withRowAnimation: .Top)
            }
            for indexPath in indexPaths {
                self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Top)
            }
            
            self.tableView.endUpdates()
        }else{
            self.tableView.reloadData()
        }
        if needScroolToBottom{
            scrollToBottom()
        }
    }
    
    // MARK: - Button Action
    func goToTopUp(){
    }
    public func showLoading(text:String = "Loading"){
        SJProgressHUD.showWaiting("text", autoRemove: false)
    }
    public func dismissLoading(){
        SJProgressHUD.dismiss()
    }
    func unlockChat(){
        UIView.animateWithDuration(0.6, animations: {
            self.archievedNotifTop.constant = 65
            self.archievedNotifView.layoutIfNeeded()
            }, completion: { _ in
                self.archievedNotifView.hidden = true
        })
    }
    func lockChat(){
        self.archievedNotifTop.constant = 65
        self.archievedNotifView.hidden = false
        UIView.animateWithDuration(0.6, animations: {
            self.archievedNotifTop.constant = 0
            self.archievedNotifView.layoutIfNeeded()
            }
        )
    }
    func confirmUnlockChat(){
        self.unlockAction()
//        if consultantRate > 0 {
//            if consultantRate > User.getUser().balance{
//                let title = NSLocalizedString("INSUFFICIENT_TITLE", comment: "Important")
//                let message = NSLocalizedString("INSUFFICIENT_MESSAGE", comment: "Suggestion")
//                let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
//                
//                // Create the actions
//                let cancelButton = NSLocalizedString("CANCEL_BUTTON", comment: "button")
//                let okAction = UIAlertAction(title: cancelButton, style: UIAlertActionStyle.Default) {
//                    _ in
//                    
//                }
//                let topUpTitle = NSLocalizedString("TOP_UP_TITLE", comment: "Important")
//                let topUpAction = UIAlertAction(title: topUpTitle, style: .Default, handler: {
//                    alertAction in
//                    self.goToTopUp()
//                })
//                // Add the actions
//                alertController.addAction(okAction)
//                alertController.addAction(topUpAction)
//                // Present the controller
//                self.presentViewController(alertController, animated: true, completion: nil)
//            }else{
//                let title = NSLocalizedString("OPEN_ARCHIVED_CHAT_TITLE", comment: "Confirmation")
//                let messageFirst = NSLocalizedString("OPEN_ARCHIVED_CHAT_MESSAGE_FIRST", comment: "Message alert")
//                let messageMiddle = "Rp \(consultantRate)"
//                let messageLast = NSLocalizedString("OPEN_ARCHIVED_CHAT_MESSAGE_LAST", comment: "Message alert ")
//                let message = "\(messageFirst) \(messageMiddle) \(messageLast)"
//                let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
//                
//                // Create the actions
//                let cancelButton = NSLocalizedString("CANCEL_BUTTON", comment: "button")
//                let okAction = UIAlertAction(title: cancelButton, style: UIAlertActionStyle.Default) {
//                    _ in
//                    
//                }
//                let openButton = NSLocalizedString("OPEN_BUTTON", comment: "button")
//                let topUpAction = UIAlertAction(title: openButton, style: .Default, handler: {
//                    alertAction in
//                    self.unlockChat()
//                })
//                // Add the actions
//                alertController.addAction(okAction)
//                alertController.addAction(topUpAction)
//                // Present the controller
//                self.presentViewController(alertController, animated: true, completion: nil)
//            }
//        }else{
//            self.unlockChat()
//            
//        }
    }
    func sendMessage(){
        commentClient.postMessage(message: inputText.value, topicId: self.topicId)
        inputText.clearValue()
        //view.endEditing(true)
        inputText.text = ""
        sendButton.enabled = false
        self.scrollToBottom()
    }
    func tapMediaDisplay(sender: ChatTapRecognizer){
        if let delegate = self.cellDelegate{
            delegate.didTapMediaCell(NSURL(string: "file://\(sender.fileLocalPath)")!, mediaName: sender.fileName)
        }else{
            let preview = ChatPreviewDocVC()
            preview.fileName = sender.fileName
            preview.url = "file://\(sender.fileLocalPath)"
            preview.roomName = QiscusUIConfiguration.sharedInstance.chatTitle
            self.navigationController?.pushViewController(preview, animated: true)
        }
        
//        self.photos = [MWPhoto]()
//        if sender.fileLocalPath != "" {
//            if sender.fileType == .Media {
//                let photo = MWPhoto(URL: NSURL(string: "file://\(sender.fileLocalPath)"))
//                photo.caption = sender.fileName
//                self.photos.append(photo)
//                
//                let browser = MWPhotoBrowser(delegate: self)
//                browser.displayActionButton = true
//                browser.displayNavArrows = false
//                browser.displaySelectionButtons = false
//                browser.zoomPhotosToFill = true
//                browser.alwaysShowControls = false
//                browser.enableGrid = false
//                browser.navigationController?.title = ""
//                self.navigationController?.pushViewController(browser, animated: true)
//            }
//        }
    }
    func tapChatFile(sender: ChatTapRecognizer){
        let url = sender.fileURL
        let fileName = sender.fileName
        
        let preview = ChatPreviewDocVC()
        preview.fileName = fileName
        preview.url = url
        preview.roomName = QiscusUIConfiguration.sharedInstance.chatTitle
        self.navigationController?.pushViewController(preview, animated: true)
    }
    func uploadImage(){
        let photoPermissions = PHPhotoLibrary.authorizationStatus()
        
        if(photoPermissions == PHAuthorizationStatus.Authorized){
            self.goToGaleryPicker()
        }else if(photoPermissions == PHAuthorizationStatus.NotDetermined){
            PHPhotoLibrary.requestAuthorization({(status:PHAuthorizationStatus) in
                switch status{
                case .Authorized:
                    self.goToGaleryPicker()
                    break
                case .Denied:
                    self.showPhotoAccessAlert()
                    break
                default:
                    self.showPhotoAccessAlert()
                    break
                }
            })
        }else{
            self.showPhotoAccessAlert()
        }
    }
    func uploadFromCamera(){
        if AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo) ==  AVAuthorizationStatus.Authorized
        {
            dispatch_async(dispatch_get_main_queue(), {
                let picker = UIImagePickerController()
                picker.delegate = self
                picker.allowsEditing = false
                picker.mediaTypes = [(kUTTypeImage as String)]
                
                picker.sourceType = UIImagePickerControllerSourceType.Camera
                self.presentViewController(picker, animated: true, completion: nil)
            })
        }else{
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { (granted :Bool) -> Void in
                dispatch_async(dispatch_get_main_queue(), {
                    self.showCameraAccessAlert()
                })
            })
        }
    }
    func iCloudOpen(){
        let documentPicker = UIDocumentPickerViewController(documentTypes: self.UTIs, inMode: UIDocumentPickerMode.Import)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = UIModalPresentationStyle.FullScreen
//        documentPicker.navigationController?.navigationBar.verticalGradientColor(QiscusUIConfiguration.sharedInstance.baseColor, bottomColor: QiscusUIConfiguration.sharedInstance.gradientColor)
        self.navigationController?.pushViewController(documentPicker, animated: true)
    }
    public func documentPicker(controller: UIDocumentPickerViewController, didPickDocumentAtURL url: NSURL) {
        SJProgressHUD.showWaiting("Processing File", autoRemove: false)
        let coordinator = NSFileCoordinator()
        coordinator.coordinateReadingItemAtURL(url, options: NSFileCoordinatorReadingOptions.ForUploading, error: nil) { (dataURL) in
            do{
                let data:NSData = try NSData(contentsOfURL: dataURL, options: NSDataReadingOptions.DataReadingMappedIfSafe)
                var fileName = dataURL.lastPathComponent?.stringByReplacingOccurrencesOfString("%20", withString: "_")
                fileName = fileName!.stringByReplacingOccurrencesOfString(" ", withString: "_")
                
                let fileNameArr = (fileName! as String).characters.split(".")
                let ext = String(fileNameArr.last!).lowercaseString
                
                // get file extension
                let isGifImage:Bool = (ext == "gif" || ext == "gif_")
                let isJPEGImage:Bool = (ext == "jpg" || ext == "jpg_")
                let isPNGImage:Bool = (ext == "png" || ext == "png_")
                //let isVideo:Bool = (ext == "mp4" || ext == "mp4_" || ext == "mov" || ext == "mov_")
                
                if isGifImage || isPNGImage || isJPEGImage{
                    var imagePath:NSURL?
                    let image = UIImage(data: data)
                    if isGifImage{
                        imagePath = dataURL
                    }
                    
                    SJProgressHUD.dismiss()
                    let title = QiscusUIConfiguration.sharedInstance.confirmationTitle
                    let text = QiscusUIConfiguration.sharedInstance.confirmationImageUploadText
                    let okText = QiscusUIConfiguration.sharedInstance.alertOkText
                    let cancelText = QiscusUIConfiguration.sharedInstance.alertCancelText
                    let previewImage = QiscusAlert().showImage(self, title: title, text: text, buttonText: okText, cancelButtonText: cancelText, iconImage: image, imageName: fileName, imagePath:imagePath)
                    previewImage.addImageAction(self.continueImageUpload)
                    
                }else{
                    
                    SJProgressHUD.dismiss()
                    let title = QiscusUIConfiguration.sharedInstance.confirmationTitle
                    let textFirst = QiscusUIConfiguration.sharedInstance.confirmationFileUploadText
                    let textMiddle = "\(fileName! as String)"
                    let textLast = QiscusUIConfiguration.sharedInstance.questionMark
                    let text = "\(textFirst) \(textMiddle) \(textLast)"
                    let okText = QiscusUIConfiguration.sharedInstance.alertOkText
                    let cancelText = QiscusUIConfiguration.sharedInstance.alertCancelText
                    let previewImage = QiscusAlert().showImage(self, title: title, text: text, buttonText: okText, cancelButtonText: cancelText, iconImage: nil, imageName: fileName! as String, imagePath:dataURL, imageData: data)
                    previewImage.addImageAction(self.continueImageUpload)
                }
            }catch _{
                SJProgressHUD.dismiss()
            }
        }
    }
    func goToIPhoneSetting(passwd: String){
        UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    // MARK: - Upload Action
    func continueImageUpload(image:UIImage?,imageName:String,imagePath:NSURL? = nil, imageNSData:NSData? = nil){
        commentClient.uploadImage(self.topicId, image: image, imageName: imageName, imagePath: imagePath, imageNSData: imageNSData)
    }
    
    // MARK: - MWPhotoBrowserDelegate
    //    func numberOfPhotosInPhotoBrowser(photoBrowser: MWPhotoBrowser!) -> UInt {
    //        return UInt(photos.count)
    //    }
    //
    //    func photoBrowser(photoBrowser: MWPhotoBrowser!, photoAtIndex index: UInt) -> MWPhotoProtocol! {
    //        if Int(index) < self.photos.count {
    //            return photos[Int(index)]
    //        }
    //        return nil
    //    }
    
    // MARK: UIImagePicker Delegate
    public func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]){
        let time = Double(NSDate().timeIntervalSince1970)
        let timeToken = UInt64(time * 10000)
        let fileType:String = info[UIImagePickerControllerMediaType] as! String
        picker.dismissViewControllerAnimated(true, completion: nil)
        
        if fileType == "public.image"{
            var imageName:String = ""
            var image = UIImage()
            var imagePath:NSURL?
            if let imageURL = info[UIImagePickerControllerReferenceURL] as? NSURL{
                imageName = imageURL.lastPathComponent!
                image = info[UIImagePickerControllerOriginalImage] as! UIImage
                
                let imageNameArr = imageName.characters.split(".")
                let imageExt:NSString = String(imageNameArr.last!).lowercaseString
                
                if imageExt.isEqualToString("gif") || imageExt.isEqualToString("gif_"){
                    imagePath = imageURL
                }
            }else{
                imageName = "\(timeToken).jpg"
                image = info[UIImagePickerControllerOriginalImage] as! UIImage
            }
            let title = QiscusUIConfiguration.sharedInstance.confirmationTitle
            let text = QiscusUIConfiguration.sharedInstance.confirmationImageUploadText
            let okText = QiscusUIConfiguration.sharedInstance.alertOkText
            let cancelText = QiscusUIConfiguration.sharedInstance.alertCancelText
            
            let previewImage = QiscusAlert().showImage(self, title: title, text: text, buttonText: okText, cancelButtonText: cancelText, iconImage: image, imageName: imageName, imagePath:imagePath)
            previewImage.addImageAction(self.continueImageUpload)
        }
    }
    public func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        picker.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: - QVCChatClient Delegate
    //    func didFinishGetChatRoom(room: QiscusRoom, consultation:ConsultationModel?){
    //        SJProgressHUD.dismiss()
    //        UIView.animateWithDuration(0.3, animations: {
    //            self.archievedNotifTop.constant = 65
    //            self.archievedNotifView.layoutIfNeeded()
    //        })
    //    }
    //    func didFailedGetChatRoom(){
    //        SJProgressHUD.dismiss()
    //    }
    //    func unAutorizedAccess(){
    //        SJProgressHUD.dismiss()
    //    }
    
    // MARK: - Load More Control
    func loadMore(){
        if self.comment.count > 0 {
            let firstComment = self.comment[0][0]
            
            if firstComment.commentBeforeId > 0 {
                commentClient.loadMoreComment(fromCommentId: firstComment.commentId, topicId: self.topicId, limit: 10)
            }else{
                self.loadMoreControl.endRefreshing()
                self.loadMoreControl.enabled = false
            }
        }
    }
    
    // MARK: - Back Button
    class func backButton(target: UIViewController, action: Selector) -> UIBarButtonItem{
        let backIcon = UIImageView()
        backIcon.contentMode = .ScaleAspectFit
        
        let backLabel = UILabel()
        
        backLabel.text = QiscusUIConfiguration.sharedInstance.backText
        backLabel.textColor = UIColor.whiteColor()
        backLabel.font = UIFont.systemFontOfSize(12)
        
        let selfBundles = NSBundle.init(forClass: Qiscus.classForCoder())
        let image = UIImage(named: "ic_back", inBundle: selfBundles, compatibleWithTraitCollection: nil)?.localizedImage()
        backIcon.image = image
        
        
        if UIApplication.sharedApplication().userInterfaceLayoutDirection == .LeftToRight {
            backIcon.frame = CGRectMake(0,0,10,15)
            backLabel.frame = CGRectMake(15,0,45,15)
        }else{
            backIcon.frame = CGRectMake(50,0,10,15)
            backLabel.frame = CGRectMake(0,0,45,15)
        }
        
        
        let backButton = UIButton(frame:CGRectMake(0,0,60,20))
        backButton.addSubview(backIcon)
        backButton.addSubview(backLabel)
        backButton.addTarget(target, action: action, forControlEvents: UIControlEvents.TouchUpInside)
        
        return UIBarButtonItem(customView: backButton)
    }
    
    func showAlert(alert alert:UIAlertController){
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func setGradientChatNavigation(withTopColor topColor:UIColor, bottomColor:UIColor, tintColor:UIColor){
        self.topColor = topColor
        self.bottomColor = bottomColor
        self.tintColor = tintColor
        if !Qiscus.sharedInstance.isPushed{
            self.navigationController?.navigationBar.verticalGradientColor(self.topColor, bottomColor: self.bottomColor)
            self.navigationController?.navigationBar.tintColor = self.tintColor
        }
    }
    func setNavigationColor(color:UIColor, tintColor:UIColor){
        self.topColor = color
        self.bottomColor = color
        self.tintColor = tintColor
        if !Qiscus.sharedInstance.isPushed{
            self.navigationController?.navigationBar.verticalGradientColor(topColor, bottomColor: bottomColor)
            self.navigationController?.navigationBar.tintColor = tintColor
        }
    }
}
