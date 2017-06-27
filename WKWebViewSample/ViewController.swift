//
//  ViewController.swift
//  WKWebViewSample
//
//  Created by magicmon on 2017. 6. 27..
//  Copyright © 2017년 magicmon. All rights reserved.
//

import UIKit
import WebKit

enum WebRequestType {
    case get
    case post(String?)
}

class ViewController: UIViewController {

    let useCookie: Bool = true
    
    lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        
        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences = preferences
        
        if #available(iOS 9.0, *) {
            configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        }
        
        if self.useCookie {
            let userContentController = WKUserContentController()
            if let script = self.makeCookiesScript() {
                let cookieScript = WKUserScript(source: script, injectionTime: WKUserScriptInjectionTime.atDocumentStart, forMainFrameOnly: false)
                userContentController.addUserScript(cookieScript)
            }
            configuration.userContentController = userContentController
        }
        
        let webView = WKWebView(frame: self.view.bounds, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.backgroundColor = UIColor.white
        webView.scrollView.backgroundColor = UIColor.clear
        
        self.view.addSubview(webView)
        
        return webView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        
        if #available(iOS 9.0, *) {
            webView.allowsLinkPreview = true
        }
        
        loadURLString("http://magicmon.github.io")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension ViewController {
    func loadURLString(_ URLString: String, requestType: WebRequestType = .get) {
        // setup URL
        if let url = URL(string: URLString) {
            var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
            if useCookie {
                request.setValue(makeCookiesValue(), forHTTPHeaderField: "Cookie")
            }
            
            switch requestType {
            case .post(let body):
                request.httpMethod = "POST"
                if let body = body {
                    let data = body.data(using: .utf8)
                    request.httpBody = data
                }
            default:
                break
            }
            
            webView.load(request)
        } else {
            print("loadURLString received invalid URL: \(URLString)")
        }
    }
    
    func makeCookiesScript() -> String? {
        guard let cookies = HTTPCookieStorage.shared.cookies else {
            return nil
        }
        
        var result = ""
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss zzz"
        
        for cookie in cookies {
            result += "document.cookie='\(cookie.name)=\(cookie.value); domain=\(cookie.domain); path=\(cookie.path); "
            if let date = cookie.expiresDate {
                result += "expires=\(dateFormatter.string(from: date)); "
            }
            if (cookie.isSecure) {
                result += "secure; "
            }
            result += "'; "
        }
        
        return result
    }
    
    func makeCookiesValue() -> String? {
        guard let cookies = HTTPCookieStorage.shared.cookies else {
            return nil
        }
        
        var cookieDic = [String: String]()
        for cookie in cookies {
            cookieDic[cookie.name] = cookie.value
        }
        
        var result = ""
        for (key, value) in cookieDic {
            result += "\(key)=\(value);"
        }
        
        return result
    }
}

// MARK: - WKNavigationDelegate
extension ViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        
        // disable user selection(long click 금지)
        webView.evaluateJavaScript("document.documentElement.style.webkitUserSelect='none'", completionHandler: nil)
        
        // disable callout(copy 금지)
        webView.evaluateJavaScript("document.documentElement.style.webkitTouchCallout='none'", completionHandler: nil)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, url.scheme != "http" && url.scheme != "https" {
            UIApplication.shared.openURL(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            let cred = URLCredential(trust: trust)
            completionHandler(.useCredential, cred)
            
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - WKUIDelegate
extension ViewController: WKUIDelegate {
    
    // this handles target=_blank links by opening them in the same view
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        
        return nil
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let uiAlertController = UIAlertController(// create new instance alert  controller
            title: "",
            message: message,
            preferredStyle: .alert)
        
        uiAlertController.addAction(
            UIAlertAction.init(title: "OK", style: .default, handler: { (UIAlertAction) in
                completionHandler()
                uiAlertController.dismiss(animated: true, completion: nil)
                
            }))
        
        //show You alert
        self.present(uiAlertController, animated: true, completion: nil)
        
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let uiAlertController = UIAlertController(// create new instance alert  controller
            title: "",
            message: message,
            preferredStyle: .alert)
        
        uiAlertController.addAction(
            UIAlertAction.init(title: "OK", style: .default, handler: { (UIAlertAction) in
                completionHandler(true)
                uiAlertController.dismiss(animated: true, completion: nil)
                
            }))
        
        uiAlertController.addAction(UIAlertAction.init(title: "Cancel", style: .cancel, handler: { (UIAlertAction) in
            completionHandler(false)
            uiAlertController.dismiss(animated: true, completion: nil)
        }))
        
        
        //show You alert
        self.present(uiAlertController, animated: true, completion: nil)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        
        let contentView = UIView()
        contentView.frame = CGRect(x: 15, y: 10, width: self.view.frame.size.width, height: 50)
        
        let textField = UITextField()
        textField.frame.size = CGSize(width: 0, height: 25)
        textField.font = UIFont.systemFont(ofSize: 15)
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.returnKeyType = .done
        textField.autocorrectionType = .no
        textField.delegate = self
        textField.placeholder = defaultText
        textField.becomeFirstResponder()
        contentView.addSubview(textField)
        
        let uiAlertController = UIAlertController(// create new instance alert  controller
            title: "",
            message: prompt,
            preferredStyle: .alert)
        
        uiAlertController.addAction(
            UIAlertAction.init(title: "OK", style: .default, handler: { (UIAlertAction) in
                if let text = textField.text {
                    completionHandler(text)
                } else {
                    completionHandler(defaultText)
                }
                
                uiAlertController.dismiss(animated: true, completion: nil)
                
            }))
        
        uiAlertController.addAction(UIAlertAction.init(title: "Cancel", style: .cancel, handler: { (UIAlertAction) in
            completionHandler(nil)
            uiAlertController.dismiss(animated: true, completion: nil)
        }))
        
        
        //show You alert
        self.present(uiAlertController, animated: true, completion: nil)
    }
}

// MARK: UITextFieldDelegate
extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

