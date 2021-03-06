import UIKit

class KeyboardViewController: UIInputViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet var keyboardView: UIView!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var numericKeys: UIView!
    @IBOutlet var bottomBar: UIView!
    @IBOutlet var tabBar: UIView!
    @IBOutlet var noDittosLabel: UILabel!
    @IBOutlet var tabTitleLabel: UILabel!
    
    @IBOutlet var backspaceButton: UIButton!
    @IBOutlet var nextKeyboardButton: UIButton!
    @IBOutlet var returnButton: UIButton!
    @IBOutlet var spaceButton: UIButton!
    @IBOutlet var decimalButton: UIButton!
    @IBOutlet var dittoButton: UIButton!
    
    @IBOutlet var addDittoTextInput: UITextView!
    @IBOutlet var addDittoView: UIView!
    @IBOutlet var categoryPicker: UIPickerView!
    @IBOutlet var addDittoTextView: UITextView!
    @IBOutlet var selectedCategory: UILabel!
    @IBOutlet var addDittoButtons: UIView!
    @IBOutlet var addDittoButton: UIButton!
    
    var keyboardHeightConstraint: NSLayoutConstraint!
    @IBOutlet var tabBarHeightConstraint: NSLayoutConstraint!
    
    let dittoStore: PendingDittoStore
    let addDittoViewController = AddDittoFromClipboardViewController()
    var backspaceTimer: DelayedRepeatTimer!
    let defaults = NSUserDefaults(suiteName: "group.io.kern.ditto")!
    
    let ADD_DITTO_TEXT_INPUT_PLACEHOLDER = "Select and copy desired text... if it doesn't appear, you may need to turn on \"Allow Full Access\" in your device's keyboard settings."
    
    var tabViews: [UIView]
    var selectedTab: Int
    var selectedRow: Int
    var selectedTabArrow: CAShapeLayer = CAShapeLayer()
    
    init() {
        dittoStore = PendingDittoStore()
        tabViews = []
        selectedTab = -1
        selectedRow = -1
        super.init(nibName: "KeyboardViewController", bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        keyboardHeightConstraint = NSLayoutConstraint(item: keyboardView,
            attribute: .Height,
            relatedBy: .Equal,
            toItem: nil,
            attribute: .NotAnAttribute,
            multiplier: 0,
            constant: getHeightForKeyboard())
        
        bottomBar.backgroundColor = UIColor(white: 0.85, alpha: 1)
        tableView.registerClass(ObjectTableViewCell.classForCoder(), forCellReuseIdentifier: "ObjectTableViewCell")
        
        categoryPicker.delegate = addDittoViewController
        categoryPicker.dataSource = addDittoViewController
        
        let tapGesture = UITapGestureRecognizer(target: self, action: Selector("tabDragged:"))
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: Selector("tabDragged:"))
        let panGesture = UIPanGestureRecognizer(target: self, action: Selector("tabDragged:"))
        tabBar.addGestureRecognizer(tapGesture)
        tabBar.addGestureRecognizer(longPressGesture)
        tabBar.addGestureRecognizer(panGesture)
        
        loadTab(0)
        selectedTabArrow = drawSelectedTabArrow(0)
        
        addDittoView.hidden = true
        
    }
    
    override func viewWillAppear(animated: Bool) {
        
        super.viewWillAppear(animated)
        
        // Keyboard height constraint must be added here rather than ViewDidLoad
        keyboardView.addConstraint(keyboardHeightConstraint)
        
        if dittoStore.isEmpty() {
            noDittosLabel.hidden = false
            tableView.hidden = true
        } else {
            noDittosLabel.hidden = true
            tableView.hidden = false
            tableView.reloadData()
        }
    
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        keyboardHeightConstraint.constant = getHeightForKeyboard()
        tabBarHeightConstraint.constant = getHeightForTabBar()
        refreshTabButtons()
        tableView.beginUpdates()
        tableView.endUpdates()
    }
    
    func loadAddDittoView() {
        categoryPicker.hidden = true
        addDittoTextView.hidden = false
        addDittoTextView.selectable = false
        selectedCategory.text = selectedCategoryFromPicker()
        NSTimer.scheduledTimerWithTimeInterval(0.3, target: self, selector: Selector("pollPasteboard"), userInfo: nil, repeats: true)
        pollPasteboard()
    }
    
    override func textDidChange(textInput: UITextInput?) {
        let proxy = textDocumentProxy 
        
        switch proxy.keyboardType! {
        case .NumberPad:
            numericKeys.hidden = false
            spaceButton.hidden = true
            returnButton.hidden = true
            decimalButton.hidden = true
            dittoButton.hidden = true

        case .DecimalPad:
            numericKeys.hidden = false
            spaceButton.hidden = true
            returnButton.hidden = true
            decimalButton.hidden = false
            dittoButton.hidden = true
            
        default:
            numericKeys.hidden = true
            spaceButton.hidden = false
            returnButton.hidden = false
            decimalButton.hidden = false
            dittoButton.hidden = false

        }
    }
    
    //==============
    // MARK: - Tabs
    
    func tabDragged(recognizer: UIGestureRecognizer) {
        
        let tab = Int(floor(recognizer.locationInView(tabBar).x / tabWidth()))
        
        if addDittoView.hidden {
            loadTab(tab)
            selectedTabArrow.hidden = false
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            // change properties here without animation
            loadTab(tab)
            selectedTabArrow.hidden = false
            CATransaction.commit()
        }
        
        addDittoView.hidden = true
        numericKeys.hidden = true
        tableView.hidden = false
        
        tabTitleLabel.hidden = dittoStore.oneCategory() || recognizer.state == .Ended
        view.setNeedsLayout()
    
    }
    
    func loadTab(tab: Int) {
        tableView.setContentOffset(CGPointZero, animated:false)
        if selectedTab == tab || dittoStore.isEmpty() { return }
        selectedTab = tab
        moveSelectedTabArrow(tab)
        selectedRow = -1
        tabTitleLabel.text = dittoStore.getCategory(selectedTab)
        tabTitleLabel.backgroundColor = colorForTab(selectedTab)
        tableView.reloadData()
    }
    
    func selectedTabArrowPath() -> CGPath {
        let h = tabBar.bounds.height
        let x = CGFloat(0.0)
        
        let path = UIBezierPath()
        path.moveToPoint(CGPointMake(x - 7, h))
        path.addLineToPoint(CGPointMake(x + 7, h))
        path.addLineToPoint(CGPointMake(x, h-7))
        path.closePath()
        
        return path.CGPath
    }
    
    func moveSelectedTabArrow(tab: Int) {
        selectedTabArrow.position = CGPointMake((CGFloat(tab) + 0.5) * tabWidth(), 0)
    }
    
    func drawSelectedTabArrow(tab: Int) -> CAShapeLayer {
        if dittoStore.isEmpty() || dittoStore.oneCategory() {
            return CAShapeLayer()
        }
        
        let shape = CAShapeLayer()
        tabBar.layer.addSublayer(shape)
        shape.opacity = 1
        shape.lineWidth = 0.0
        shape.lineJoin = kCALineJoinMiter
        shape.strokeColor = UIColor.whiteColor().CGColor
        shape.fillColor = UIColor.whiteColor().CGColor
        
        shape.path = selectedTabArrowPath()
        shape.zPosition = 1
        
        return shape
    }
    
    func refreshTabButtons() {
        
        if dittoStore.isEmpty() || dittoStore.oneCategory() {
            return
        }
        
        for tv in tabViews {
            tv.removeFromSuperview()
        }
        
        let w = tabWidth()
        let h = tabBar.bounds.height
        
        tabViews = (0..<countTabs()).map({ i in
            
            let tab = UIView(frame: CGRectMake(CGFloat(i) * w, 0, w, h))
            tab.backgroundColor =  self.colorForTab(i)
            
            let tabLabel = UILabel(frame: CGRectMake(8, 0, w - 16, h))
            tabLabel.textColor = UIColor.whiteColor()
            tabLabel.text = self.dittoStore.getCategory(i)
            tabLabel.font = tabLabel.font.fontWithSize(14.0)
            tabLabel.textAlignment = .Center
            tabLabel.lineBreakMode = NSLineBreakMode.ByClipping
            self.truncateToLastFullLetter(tabLabel, width: w - 16)
            
            tab.addSubview(tabLabel)
            self.tabBar.addSubview(tab)
            
            return tab
        })
        
        tabBar.bringSubviewToFront(tabTitleLabel)
        
        moveSelectedTabArrow(selectedTab)
        
    }
    
    func countTabs() -> Int {
        return dittoStore.countCategories()
    }
    
    func tabWidth() -> CGFloat {
        return UIScreen.mainScreen().bounds.width / CGFloat(countTabs())
    }
    
    func colorForTab(index: Int) -> UIColor {
        let whiteMix = 0.4 * (CGFloat(index) / CGFloat(dittoStore.countCategories()))
        let rbComponent = min(1, 0.6 + whiteMix)
        return UIColor(red: rbComponent, green: whiteMix * 1.7, blue: rbComponent, alpha: 1)
    }
    
    //=======================
    // MARK: - Row Selection
    
    var selectedIndexPath: NSIndexPath {
        return NSIndexPath(forRow: selectedRow, inSection: 0)
    }
    
    func selectRow(row: Int) {
        
        if selectedRow == row { return }
        
        if selectedRow >= 0 {
            let cell = tableView.cellForRowAtIndexPath(selectedIndexPath) as? ObjectTableViewCell
            cell?.truncated = true
        }
        
        selectedRow = row
        let cell = tableView.cellForRowAtIndexPath(selectedIndexPath) as! ObjectTableViewCell
        cell.truncated = false
        
        tableView.beginUpdates()
        tableView.endUpdates()

    }
    
    //==============================
    // MARK: - Table View Callbacks
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if dittoStore.isEmpty() {
            return 0
        } else {
            return dittoStore.countInCategory(selectedTab)
        }
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let text = dittoStore.getDittoPreviewInCategory(selectedTab, index: indexPath.row)
        return ObjectTableViewCell.heightForText(text, truncated: selectedRow != indexPath.row, disclosure: false)
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("ObjectTableViewCell", forIndexPath: indexPath) as! ObjectTableViewCell
        let text = dittoStore.getDittoPreviewInCategory(selectedTab, index: indexPath.row)
        cell.setText(text, disclosure: false)
        cell.truncated = selectedRow != indexPath.row
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        let proxy = textDocumentProxy 
        let ditto = dittoStore.getDittoInCategory(selectedTab, index: indexPath.row)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        let (newDitto, cursorRewind) = findCursorRange(ditto)
        proxy.insertText(newDitto)
        dispatch_async(dispatch_get_main_queue(), {
            proxy.adjustTextPositionByCharacterOffset(-cursorRewind)
        })
        
    }
    
    @IBAction func dittoLongPressed(sender: UILongPressGestureRecognizer) {
        if sender.state != .Began { return }
        let p = sender.locationInView(tableView)
        if let indexPath = tableView.indexPathForRowAtPoint(p) {
            selectRow(indexPath.row)
        }
    }
    
    //==========================
    // MARK: - Button Callbacks
    
    @IBAction func nextKeyboardButtonClicked() {
        advanceToNextInputMode()
    }
    
    @IBAction func dittoButtonClicked() {
        if dittoStore.isEmpty() {
            return
        } else if addDittoView.hidden {
            loadAddDittoView()
            addDittoView.hidden = false
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            // change properties here without animation
            selectedTabArrow.hidden = true
            CATransaction.commit()
            
        } else {
            addDittoView.hidden = true
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            // change properties here without animation
            selectedTabArrow.hidden = false
            CATransaction.commit()
        }
    }
    
    @IBAction func returnButtonClicked() {
        let proxy = textDocumentProxy 
        proxy.insertText("\n")
    }
    
    @IBAction func backspaceButtonDown() {
        backspaceFire()
        backspaceTimer = DelayedRepeatTimer(delay: 0.5, ti: 0.1, target: self, selector: Selector("backspaceFire"))
    }
    
    @IBAction func backspaceButtonUp() {
        backspaceTimer.invalidate()
        backspaceTimer = nil
    }
    
    @IBAction func spaceButtonClicked() {
        let proxy = textDocumentProxy 
        proxy.insertText(" ")
    }
    
    @IBAction func numberClicked(button: UIButton) {
        let proxy = textDocumentProxy 
        let char = button.titleLabel?.text
        proxy.insertText(char!)
    }
    
    @IBAction func pasteButtonClicked(sender: UIButton) {
        if let pasteBoardString = UIPasteboard.generalPasteboard().string {
            addDittoTextInput.text = pasteBoardString
        }
    }
    
    @IBAction func addDittoButtonClicked(sender: UIButton) {
        if addDittoTextInput.text != ADD_DITTO_TEXT_INPUT_PLACEHOLDER {
            let categoryIndex = categoryPicker.selectedRowInComponent(0)
            dittoStore.addDittoToCategory(categoryIndex, text: addDittoTextInput.text!)
            tableView.reloadData()
            addDittoButton.setTitle("Your ditto has been saved!", forState: .Normal)
            addDittoButton.enabled = false
        }
    }
    
    @IBAction func categoryBarTapped(sender: UITapGestureRecognizer) {
        // If full access isn't allowed (pasteboard isn't accessible), we don't want to be able to select a category
        if let pasteBoardString = UIPasteboard.generalPasteboard().string {
            if categoryPicker.hidden {
                selectedCategory.text = "Done"
                categoryPicker.hidden = false
                addDittoButtons.hidden = true
                addDittoTextView.hidden = true
            } else {
                selectedCategory.text = selectedCategoryFromPicker()
                categoryPicker.hidden = true
                addDittoButtons.hidden = false
                addDittoTextView.hidden = false
            }
        }
    }
    //=================
    // MARK: - Helpers
    
    func truncateToLastFullLetter(label: UILabel, width: CGFloat) {
        while label.intrinsicContentSize().width > width {
            label.text = label.text!.substringToIndex(label.text!.endIndex.predecessor())
        }
    }
    
    func backspaceFire() {
        let proxy = textDocumentProxy 
        proxy.deleteBackward()
    }
    
    func findCursorRange(s: String) -> (String, Int) {
        let length = s.characters.count
        let regex = try! NSRegularExpression(pattern: "___+", options: [])
        let match = regex.rangeOfFirstMatchInString(s, options: [], range: NSMakeRange(0, length))
        
        if (match.location == NSNotFound) {
            return (s, 0)
        } else {
            let start = s.startIndex.advancedBy(match.location)
            let end = start.advancedBy(match.length)
            let range = Range(start: start, end: end)
            let newS = s.stringByReplacingCharactersInRange(range, withString: "")
            return (newS, length - match.location - match.length)
        }
    }
    
    func selectedCategoryFromPicker() -> String {
        let categoryIndex = categoryPicker.selectedRowInComponent(0)
        return dittoStore.getCategory(categoryIndex)
    }
    
    func getHeightForKeyboard() -> CGFloat {
        
        let screenHeight = UIScreen.mainScreen().bounds.height
        let screenWidth = UIScreen.mainScreen().bounds.width
        
        if screenWidth > screenHeight {
            return screenHeight * 0.6
        } else {
            return min(260, screenHeight * 0.7)
        }
        
    }
    
    func getHeightForTabBar() -> CGFloat {
        if dittoStore.oneCategory() {
            return 0
        } else {
            return 35
        }
    }
    
    func resetAddDittoButton() {
        addDittoButton.setTitle("Add Ditto", forState: .Normal)
        addDittoButton.enabled = true
    }
    
    func pollPasteboard() {
        if let pasteBoardString = UIPasteboard.generalPasteboard().string {
            if pasteBoardString != addDittoTextInput.text {
                addDittoTextInput.text = pasteBoardString
                resetAddDittoButton()
            }
        } else {
            addDittoTextInput.text = ADD_DITTO_TEXT_INPUT_PLACEHOLDER
        }
    }
}
