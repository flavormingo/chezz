#!/usr/bin/env swift
// Flattens a 1024×1024 PNG onto opaque white (App Store icons must have no alpha) → icon-1024.png.
// Usage: swift make-icon.swift <icon.png> <output-dir>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
let inPath = args.count > 1 ? args[1] : "\(NSHomeDirectory())/Desktop/icon.png"
let outDir = args.count > 2 ? args[2] : "."
let S = 1024

guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: inPath) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fputs("Could not load \(inPath)\n", stderr); exit(1)
}

let rect = CGRect(x: 0, y: 0, width: S, height: S)
let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fill(rect)
ctx.draw(image, in: rect)

let url = URL(fileURLWithPath: "\(outDir)/icon-1024.png") as CFURL
let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
print("Wrote icon-1024.png (opaque, flattened on white)")
