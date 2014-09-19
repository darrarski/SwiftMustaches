//
//  PhotoEditorViewController.swift
//  SwiftMustaches
//
//  Created by Dariusz Rybicki on 18/09/14.
//  Copyright (c) 2014 EL Passion. All rights reserved.
//

import UIKit
import Photos

class PhotoEditorViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    let adjustmentDataFormatIdentifier = "com.elpassion.SwiftMustaches.MustacheAnnotator"
    let adjustmentDataformatVersion = "0.1"
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var openBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var saveBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    
    var input: PHContentEditingInput? {
        didSet {
            if let input = input {
                photoImageView.image = annotate(image: input.displaySizeImage)
            }
            else {
                photoImageView.image = nil
            }
            updateUI()
        }
    }
    
    var asset: PHAsset?
    
    private var loading: Bool = false {
        didSet {
            updateUI()
        }
    }
    
    private var saving: Bool = false {
        didSet {
            updateUI()
        }
    }
    
    // MARK: - UI
    
    private func updateUI() {
        dispatch_async(dispatch_get_main_queue(), { [weak self] () -> Void in
            if let strongSelf = self {
                let isLoading = strongSelf.loading
                let isSaving = strongSelf.saving
                let isInputSet = (strongSelf.input != nil)
                strongSelf.photoImageView.hidden = isLoading || !isInputSet
                strongSelf.openBarButtonItem.enabled = !isLoading && !isSaving
                strongSelf.saveBarButtonItem.enabled = !isLoading && !isSaving && isInputSet
                if isLoading || isSaving {
                    strongSelf.activityIndicatorView.startAnimating()
                }
                else {
                    strongSelf.activityIndicatorView.stopAnimating()
                }
            }
        })
    }
    
    // MARK: - UI Actions
    
    @IBAction func openBarButtonItemAction(sender: UIBarButtonItem) {
        openPhoto()
    }
    
    @IBAction func saveBarButtonItemAction(sender: UIBarButtonItem) {
        savePhoto()
    }
    
    // MARK: - Opening photo
    
    private func openPhoto() {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = UIImagePickerControllerSourceType.SavedPhotosAlbum
        imagePicker.delegate = self
        loading = true
        presentViewController(imagePicker, animated: true, completion: nil)
    }
    
    // MARK: - Saving photo
    
    private func savePhoto() {
        if self.input == nil {
            NSLog("Error: can't save, no input")
            return
        }
        let input = self.input!
        
        if self.asset == nil {
            NSLog("Error: can't save, no asset")
            return
        }
        let asset = self.asset!
        
        saving = true
        
        let output = PHContentEditingOutput(contentEditingInput: input)
        
        let adjustmentDataData = NSKeyedArchiver.archivedDataWithRootObject("mustache")
        output.adjustmentData = PHAdjustmentData(
            formatIdentifier: adjustmentDataFormatIdentifier,
            formatVersion: adjustmentDataformatVersion,
            data: adjustmentDataData)
        
        let fullSizeImageUrl = input.fullSizeImageURL
        let fullSizeImage = UIImage(contentsOfFile: fullSizeImageUrl.path!)
        let fullSizeAnnotatedImage = annotate(image: fullSizeImage)
        let fullSizeAnnotatedImageData = UIImageJPEGRepresentation(fullSizeAnnotatedImage, 0.9)
        
        var error: NSError?
        let success = fullSizeAnnotatedImageData.writeToURL(output.renderedContentURL, options: .AtomicWrite, error: &error)
        if !success {
            NSLog("Error when writing file: \(error)")
            saving = false
            return
        }
        
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({ [weak self] () -> Void in
            if self == nil {
                NSLog("Error: aborting due to VC deallocation")
                return
            }
            
            if self!.asset == nil {
                NSLog("Error: can't perform changes, no asset")
                self!.saving = false
                return
            }
            let asset = self!.asset
            
            let request = PHAssetChangeRequest(forAsset: asset)
            request.contentEditingOutput = output
            
        }, completionHandler: { [weak self] (success, error) -> Void in
            if !success {
                NSLog("Error saving changes: \(error)")
                self?.saving = false
                return
            }
            
            NSLog("Photo changes performed successfully")
            self?.saving = false
        })
    }
    
    // MARK: - Annotating
    
    private func annotate(#image: UIImage) -> UIImage {
        let mustacheImage = UIImage(named: "mustache")
        let mustacheAnnotator = MustacheAnnotator(mustacheImage: mustacheImage)
        return mustacheAnnotator.annotatedImage(sourceImage: image)
    }

    // MARK: - UIImagePickerControllerDelegate
    
    func imagePickerController(picker: UIImagePickerController!, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]!)  {
        let assetUrlOptional: NSURL? = info[UIImagePickerControllerReferenceURL] as? NSURL
        if assetUrlOptional == nil {
            NSLog("Error: no asset URL")
            loading = false
            return
        }
        let assetUrl = assetUrlOptional!
        
        let fetchResult = PHAsset.fetchAssetsWithALAssetURLs([ assetUrl ], options: nil)
        if fetchResult.firstObject == nil {
            NSLog("Error: asset not fetched")
            loading = false
            return
        }
        let asset = fetchResult.firstObject! as PHAsset
        
        if !asset.canPerformEditOperation(PHAssetEditOperation.Content) {
            NSLog("Error: asset can't be edited")
            loading = false
            return
        }
        
        dismissViewControllerAnimated(true, completion: nil)
        
        let options = PHContentEditingInputRequestOptions()
        options.canHandleAdjustmentData = { (adjustmentData) -> Bool in
            return adjustmentData.formatIdentifier == self.adjustmentDataFormatIdentifier && adjustmentData.formatVersion == self.adjustmentDataformatVersion
        }
        
        asset.requestContentEditingInputWithOptions(options, completionHandler: { [weak self] (input, info) -> Void in
            if self == nil {
                NSLog("Error: aborting due to VC deallocation")
                return
            }
            
            self!.asset = asset
            self!.input = input
            self!.loading = false
        })
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        dismissViewControllerAnimated(true, completion: nil)
        loading = false
    }
    
}
