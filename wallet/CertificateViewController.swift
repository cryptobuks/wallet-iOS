//
//  CertificateViewController.swift
//  wallet
//
//  Created by Chris Downie on 10/13/16.
//  Copyright © 2016 Learning Machine, Inc. All rights reserved.
//

import UIKit
import WebKit
import BlockchainCertificates
import JSONLD

class CertificateViewController: UIViewController {
    var delegate : CertificateViewControllerDelegate?
    
    public let certificate: Certificate
    private let bitcoinManager = CoreBitcoinManager()

    @IBOutlet weak var webView: WKWebView!
    
    @IBOutlet weak var shareButton: UIBarButtonItem!
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var verifyButton: UIBarButtonItem!
    @IBOutlet weak var progressView: UIProgressView!
    private var inProgressRequest : CommonRequest?
    
    
    init(certificate: Certificate) {
        self.certificate = certificate

        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadWebView();

        self.title = certificate.title
        
        shareButton.isEnabled = (certificate.assertion.uid != Identifiers.sampleCertificateUID)
        
        renderCertificate()
        stylize()
        
        Analytics.shared.track(event: .viewed, certificate: certificate)
    }
    
    func loadWebView() {
        let preferences = WKPreferences();
        let webConfiguration = WKWebViewConfiguration();
        webConfiguration.preferences = preferences;
        let webView = WKWebView(frame: .zero, configuration: webConfiguration);

        webView.translatesAutoresizingMaskIntoConstraints = false;
        view.addSubview(webView);
        
        let constraints = [
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: toolbar.topAnchor)
        ]

        NSLayoutConstraint.activate(constraints)
        
        
        let file = Bundle.main.url(forResource: "certificate", withExtension: "html")
        let webComponentPolyfill = Bundle.main.url(forResource: "webcomponents-hi-ce", withExtension: "js")!
        let webComponentPath = Bundle.main.url(forResource: "blockchain-certificate", withExtension: "html")!
        
        
        let demoJavascript = "function changeTitle() { document.body.getElementsByTagName('h1')[0].innerText = \"Hello there\"; }    document.addEventListener(\"DOMContentLoaded\", function(event) {    changeTitle();    });"

        let contentFormat = try! String(contentsOf: file!)
        let polyfillContent = try! String(contentsOf: webComponentPolyfill)
//        let contents = String(format: contentFormat, polyfillContent, webComponentPath.absoluteString, certificate.assertion.uid)
        
        let contents = String(format: contentFormat, demoJavascript);
        

        webView.loadHTMLString(contents, baseURL: Paths.certificatesDirectory)
        
        self.webView = webView
    }
    
    func renderCertificate() {
//        renderedCertificateView.certificateIcon.image = UIImage(data:certificate.issuer.image)
//        renderedCertificateView.nameLabel.text = "\(certificate.recipient.givenName) \(certificate.recipient.familyName)"
//        renderedCertificateView.titleLabel.text = certificate.title
//        renderedCertificateView.subtitleLabel.text = certificate.subtitle
//        renderedCertificateView.descriptionLabel.text = certificate.description
//        renderedCertificateView.sealIcon.image = UIImage(data: certificate.image)
//        
//        certificate.assertion.signatureImages.forEach { (signatureImage) in
//            guard let image = UIImage(data: signatureImage.image) else {
//                return
//            }
//            renderedCertificateView.addSignature(image: image, title: signatureImage.title)
//        }
    }
    
    func stylize() {
        toolbar.tintColor = Colors.brandColor
        progressView.tintColor = Colors.brandColor
    }
    
    // MARK: Actions
    @IBAction func shareTapped(_ sender: UIBarButtonItem) {
        // TODO: Guard against sample cert
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let shareFileAction = UIAlertAction(title: NSLocalizedString("Share Certificate File", comment: "Action to share certificate file, presented in an action sheet."), style: .default) { [weak self] _ in
            self?.shareCertificateFile()
        }
        let shareURLAction = UIAlertAction(title: NSLocalizedString("Share Certificate URL", comment: "Actoin to share the certificate's hosting URL, presented in an action sheet."), style: .default) { [weak self] _ in
            self?.shareCertificateURL()
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel the action sheet."), style: .cancel, handler: nil)
        
        alertController.addAction(shareURLAction)
        alertController.addAction(shareFileAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func verifyTapped(_ sender: UIBarButtonItem) {
        Analytics.shared.track(event: .validated, certificate: certificate)
        
        // Check for the Sample Certificate
        guard certificate.assertion.uid != Identifiers.sampleCertificateUID else {
            let alert = UIAlertController(
                title: NSLocalizedString("Sample Certificate", comment: "Title for our specific warning about validating a sample certificate"),
                message: NSLocalizedString("This is a sample certificate that cannot be verified. Real certificates will perform a live validation process.", comment: "Explanation for why you can't validate the sample certificate."),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Confirm action"), style: .default, handler: nil))
            
            present(alert, animated: true, completion: nil)
            
            return
        }
        
        verifyButton.isEnabled = false
        verifyButton.title = NSLocalizedString("Verifying...", comment: "Verifying a certificate is currently in progress")
        progressView.progress = 0.5
        progressView.isHidden = false
        
        let validationRequest = CertificateValidationRequest(
            for: certificate,
            bitcoinManager: bitcoinManager,
            jsonld: JSONLD.shared) { [weak self] (success, error) in
                let title : String!
                let message : String!
                if success {
                    title = NSLocalizedString("Success", comment: "Title for a successful certificate validation")
                    message = NSLocalizedString("This is a valid certificate!", comment: "Message for a successful certificate validation")
                } else {
                    title = NSLocalizedString("Invalid", comment: "Title for a failed certificate validation")
                    message = NSLocalizedString(error!, comment: "Specific error message for an invalid certificate.")
                }

                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Confirm action"), style: .default, handler: nil))
                
                OperationQueue.main.addOperation {
                    self?.present(alert, animated: true, completion: nil)
                    self?.inProgressRequest = nil
                    self?.verifyButton.isEnabled = true
                    self?.verifyButton.title = NSLocalizedString("Verify", comment: "Action button. Tap this to verify a certificate.")
                    self?.progressView.progress = 1
                    self?.progressView.isHidden = true
                }
        }
        validationRequest?.delegate = self
        validationRequest?.start()
        self.inProgressRequest = validationRequest
    }
    
    @IBAction func deleteTapped(_ sender: UIBarButtonItem) {
        let certificateToDelete = certificate
        let title = NSLocalizedString("Be careful", comment: "Caution title presented when attempting to delete a certificate.")
        let message = NSLocalizedString("If you delete this certificate and don't have a backup, then you'll have to ask the issuer to send it to you again if you want to recover it. Are you sure you want to delete this certificate?", comment: "Explanation of the effects of deleting a certificate.")
        let delete = NSLocalizedString("Delete", comment: "Confirm delete action")
        let cancel = NSLocalizedString("Cancel", comment: "Cancel action")
        
        let prompt = UIAlertController(title: title, message: message, preferredStyle: .alert)
        prompt.addAction(UIAlertAction(title: delete, style: .destructive, handler: { [weak self] (_) in
            _ = self?.navigationController?.popViewController(animated: true)
            self?.delegate?.delete(certificate: certificateToDelete)
        }))
        prompt.addAction(UIAlertAction(title: cancel, style: .cancel, handler: nil))
        
        present(prompt, animated: true, completion: nil)
    }
    
    // Share actions
    func shareCertificateFile() {
        // Moving the file to a temporary directory.
        let filePath = "\(NSTemporaryDirectory())/certificate.json"
        let url = URL(fileURLWithPath: filePath)
        do {
            try certificate.file.write(to: url)
        } catch {
            print("Failed to write temporary URL")
            
            let title = NSLocalizedString("Couldn't share certificate.", comment: "Alert title when sharing a certificate fails.")
            let message = NSLocalizedString("Something went wrong preparing that file for sharing. Try again later.", comment: "Alert message when sharing a certificate fails. Generic error.")
            let okay = NSLocalizedString("OK", comment: "Confirm action")
            
            let errorAlert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            errorAlert.addAction(UIAlertAction(title: okay, style: .default, handler: nil))
            present(errorAlert, animated: true, completion: nil)
            return
        }
        
        let items : [Any] = [ url ]
        
        let shareController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        let capturedCertificate = certificate
        shareController.completionWithItemsHandler = { (activity, completed, _, _) in
            if completed {
                Analytics.shared.track(event: .shared, certificate: capturedCertificate)
            }
        }
        
        self.present(shareController, animated: true, completion: nil)
    }
    
    func shareCertificateURL() {
        let url = certificate.assertion.id
        let items : [Any] = [ url ]
        
        let shareController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        let capturedCertificate = certificate
        shareController.completionWithItemsHandler = { (activity, completed, _, _) in
            if completed {
                Analytics.shared.track(event: .shared, certificate: capturedCertificate)
            }
        }
        
        self.present(shareController, animated: true, completion: nil)
    }
}

extension CertificateViewController : CertificateValidationRequestDelegate {
    func certificateValidationStateChanged(from: ValidationState, to: ValidationState) {
        var percentage : Float? = nil
        
        switch to {
        case .notStarted:
            percentage = 0.1
        case .assertingChain:
            percentage = 0.2
        case .computingLocalHash:
            percentage = 0.3
        case .fetchingRemoteHash:
            percentage = 0.4
        case .comparingHashes:
            percentage = 0.5
        case .checkingIssuerSignature:
            percentage = 0.6
        case .checkingRevokedStatus:
            percentage = 0.7
        case .success:
            percentage = 1
        case .failure:
            percentage = 1
        case .checkingReceipt:
            percentage = 0.8
        case .checkingMerkleRoot:
            percentage = 0.9
        }
        
        if percentage != nil {
            UIView.animate(withDuration: 0.1, animations: { 
                self.progressView.progress = percentage!
            })
        }
    }
}

protocol CertificateViewControllerDelegate : class {
    func delete(certificate: Certificate)
}
