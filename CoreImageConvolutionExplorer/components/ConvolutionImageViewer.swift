//
//  ConvolutionImageViewer.swift
//  CoreImageConvolutionExplorer
//
//  Created by Simon Gladman on 17/03/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//

import UIKit
import GLKit

class ConvolutionImageViewer: UIView
{
    let railroadImage = CIImage(image: UIImage(named: "railroad.jpg")!)!
    
    let makeOpaqueKernel = CIColorKernel(string: "kernel vec4 makeOpaque(__sample pixel) { return vec4(pixel.rgb, 1.0); }")
    
    let imageView = OpenGLImageView()
    
    let biasSlider = LabelledSlider(title: "Bias",
        minimumValue: 0,
        maximumValue: 1)
    
    let normaliseButton = LabelledSwitch(title: "Normalize",
        on: true)
    
    let premultiplyButton = LabelledSwitch(title: "Premultiply",
        on: true)
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
     
        addSubview(imageView)
        addSubview(biasSlider)
        addSubview(normaliseButton)
        addSubview(premultiplyButton)
        
        imageView.image = railroadImage
        
        biasSlider.addTarget(self,
            action: #selector(ConvolutionImageViewer.applyConvolutionKernel),
            forControlEvents: .ValueChanged)
        
        normaliseButton.addTarget(self,
            action: #selector(ConvolutionImageViewer.applyConvolutionKernel),
            forControlEvents: .ValueChanged)
        
        premultiplyButton.addTarget(self,
            action: #selector(ConvolutionImageViewer.applyConvolutionKernel),
            forControlEvents: .ValueChanged)
    }

    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToSuperview()
    {
        super.didMoveToSuperview()
        
        enabled = false
    }
    
    var weights: [CGFloat]?
    {
        didSet
        {
            if weights?.count != 9 && weights?.count != 25 && weights?.count != 49
            {
                fatalError("Weights array is wrong length!")
            }
            
            enabled = weights != nil
            
            applyConvolutionKernel()
        }
    }
    
    var enabled = false
    {
        didSet
        {
            biasSlider.enabled = enabled
            normaliseButton.enabled = enabled
            alpha = enabled ? 1 : 0.5
        }
    }
    
    func normaliseWeightsArray(weights: [CGFloat]?, normalise: Bool) -> [CGFloat]?
    {
        guard let weights = weights else
        {
            return nil
        }
        
        if !normalise
        {
            return weights
        }
        
        let sum = weights.reduce(0, combine: +)
        
        return sum == 0 ?
            weights :
            weights.map({ $0 / sum })
    }
    
    func applyConvolutionKernel()
    {
        guard let weights = normaliseWeightsArray(weights, normalise: normaliseButton.on) else
        {
            return
        }
        
        let filterName: String
        
        switch weights.count
        {
        case 9:
            filterName = "CIConvolution3X3"
        case 25:
            filterName = "CIConvolution5X5"
        default:
            filterName = "CIConvolution7X7"
        }
        
        let weightsVector: CIVector = CIVector(values: weights, count: weights.count)
        
        let finalImage = railroadImage.imageByApplyingFilter(filterName,
            withInputParameters: [
                kCIInputWeightsKey: weightsVector,
                kCIInputBiasKey: CGFloat(biasSlider.value)]).imageByCroppingToRect(railroadImage.extent)
        
        // Two seperate approaches to make opaque to mirror
        // book content. The CIColorMatrix technique could
        // can be replicated by chaning the `makeOpaqueKernel`'s
        // code to:
        //
        // 'return vec4(unpremultiply(pixel).rgb, 1.0)'
        if premultiplyButton.on
        {
            imageView.image = makeOpaqueKernel?.applyWithExtent(railroadImage.extent,
                arguments: [finalImage])
        }
        else
        {
            imageView.image = finalImage
                .imageByApplyingFilter("CIColorMatrix", withInputParameters: [ "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1)])
            .imageByCroppingToRect(finalImage.extent)
        }
    }
    
    override func layoutSubviews()
    {
        imageView.frame = bounds
        imageView.setNeedsDisplay()
        
        let buttonY = frame.height - biasSlider.intrinsicContentSize().height - normaliseButton.intrinsicContentSize().height - 20
        
        normaliseButton.frame = CGRect(x: 0,
            y: buttonY,
            width: frame.width / 2 - 5,
            height: normaliseButton.intrinsicContentSize().height)

        premultiplyButton.frame = CGRect(x: frame.width / 2 + 5,
            y: buttonY,
            width: frame.width / 2 - 5,
            height: normaliseButton.intrinsicContentSize().height)
        
        biasSlider.frame = CGRect(x: 0,
            y: frame.height - biasSlider.intrinsicContentSize().height - 10,
            width: frame.width,
            height: biasSlider.intrinsicContentSize().height)
    }
}

// ------------------------------------------------------

// MARK: LabelledControl

class LabelledControl: UIControl
{
    let label = UILabel(frame: CGRectZero)
    let title: String
    
    init(title: String)
    {
        self.title = title

        super.init(frame: CGRectZero)

        layer.cornerRadius = 5
        layer.borderColor = UIColor.lightGrayColor().CGColor
        layer.borderWidth = 1

        addSubview(label)

        updateLabel()
    }

    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateLabel()
    {
        label.text = title
    }
    
    override func layoutSubviews()
    {
        label.frame = CGRect(x: 0,
            y: 0,
            width: frame.width,
            height: frame.midY).insetBy(dx: 5, dy: 5)
    }
}

// MARK: LabelledSwitch

class LabelledSwitch: LabelledControl
{
    private let onOffSwitch = UISwitch()
    
    required init(title: String, on: Bool)
    {
        super.init(title: title)
        
        onOffSwitch.on = on
        
        onOffSwitch.addTarget(self,
            action: #selector(LabelledSwitch.switchChangeHandler),
            forControlEvents: .ValueChanged)
        
        addSubview(onOffSwitch)
    }

    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    var on: Bool
    {
        set
        {
            onOffSwitch.on = on
        }
        get
        {
            return onOffSwitch.on
        }
    }
    
    func switchChangeHandler()
    {
        on = onOffSwitch.on
        
        sendActionsForControlEvents(.ValueChanged)
    }

    override func intrinsicContentSize() -> CGSize
    {
        return CGSize(width: label.intrinsicContentSize().width + onOffSwitch.intrinsicContentSize().width + 10,
            height: max(label.intrinsicContentSize().height, onOffSwitch.intrinsicContentSize().height) + 10)
    }
    
    override func layoutSubviews()
    {
        label.frame = CGRect(x: 0,
            y: 0,
            width: frame.midX,
            height: frame.height).insetBy(dx: 5, dy: 5)
        
        onOffSwitch.frame = CGRect(x: frame.width - onOffSwitch.intrinsicContentSize().width - 10,
            y: 0,
            width: frame.width / 2,
            height: frame.height).insetBy(dx: 5, dy: 5)
    }
}

// MARK: LabelledSlider

class LabelledSlider: LabelledControl
{
    private let slider = UISlider(frame: CGRectZero)
    
    required init(title: String, minimumValue: Float = 0, maximumValue: Float = 1)
    {
        super.init(title: title)
        
        slider.minimumValue = minimumValue
        slider.maximumValue = maximumValue
        
        slider.addTarget(self,
            action: #selector(LabelledSlider.sliderChangeHandler),
            forControlEvents: .ValueChanged)

        addSubview(slider)
    }

    required init(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }

    var value: Float = 0
    {
        didSet
        {
            slider.value = Float(value)
            updateLabel()
        }
    }

    func sliderChangeHandler()
    {
        value = slider.value
        
        sendActionsForControlEvents(.ValueChanged)
    }
    
    override func updateLabel()
    {
        label.text = title + ": " + (NSString(format: "%.3f", Float(value)) as String)
    }
    
    override func intrinsicContentSize() -> CGSize
    {
        return CGSize(width: 100,
            height: label.intrinsicContentSize().height + slider.intrinsicContentSize().height + 10)
    }
    
    override func layoutSubviews()
    {
        label.frame = CGRect(x: 0,
            y: 0,
            width: frame.width,
            height: frame.height / 2).insetBy(dx: 5, dy: 5)
        
        slider.frame = CGRect(x: 0,
            y: frame.height / 2,
            width: frame.width,
            height: frame.height / 2).insetBy(dx: 5, dy: 5)
    }
}

// ------------------------------------------------------

// MARK: OpenGLImageView

class OpenGLImageView: GLKView
{
    let eaglContext = EAGLContext(API: .OpenGLES2)
    
    lazy var ciContext: CIContext =
    {
        [unowned self] in
        
        return CIContext(EAGLContext: self.eaglContext,
            options: [kCIContextWorkingColorSpace: NSNull()])
    }()
    
    override init(frame: CGRect)
    {
        super.init(frame: frame, context: eaglContext)
    
        context = self.eaglContext
        delegate = self
    }

    override init(frame: CGRect, context: EAGLContext)
    {
        fatalError("init(frame:, context:) has not been implemented")
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// The image to display
    var image: CIImage?
    {
        didSet
        {
            setNeedsDisplay()
        }
    }
}

extension OpenGLImageView: GLKViewDelegate
{
    func glkView(view: GLKView, drawInRect rect: CGRect)
    {
        guard let image = image else
        {
            return
        }
   
        let targetRect = image.extent.aspectFitInRect(
            target: CGRect(origin: CGPointZero,
                size: CGSize(width: drawableWidth,
                    height: drawableHeight)))
        
        let ciBackgroundColor = CIColor(
            color: backgroundColor ?? UIColor.whiteColor())
        
        ciContext.drawImage(CIImage(color: ciBackgroundColor),
            inRect: CGRect(x: 0,
                y: 0,
                width: drawableWidth,
                height: drawableHeight),
            fromRect: CGRect(x: 0,
                y: 0,
                width: drawableWidth,
                height: drawableHeight))
        
        ciContext.drawImage(image,
            inRect: targetRect,
            fromRect: image.extent)
    }
}

extension CGRect
{
    func aspectFitInRect(target target: CGRect) -> CGRect
    {
        let scale: CGFloat =
        {
            let scale = target.width / self.width
            
            return self.height * scale <= target.height ?
                scale :
                target.height / self.height
        }()
        
        let width = self.width * scale
        let height = self.height * scale
        let x = target.midX - width / 2
        let y = target.midY - height / 2
        
        return CGRect(x: x,
            y: y,
            width: width,
            height: height)
    }
}