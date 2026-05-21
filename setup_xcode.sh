#!/bin/bash
# ============================================
# VoiceMate + MemoEase — Xcode 一键设置脚本
# 在 Mac 终端运行: bash setup_xcode.sh
# ============================================

echo "🔧 Setting up VoiceMate & MemoEase for Xcode..."

cd "$(dirname "$0")"

# ----- VoiceMate -----
echo ""
echo "📱 [1/2] Setting up VoiceMate..."

cd VoiceMate

# Check if xcodeproj exists, if not generate from Package.swift
if [ ! -d "VoiceMate.xcodeproj" ]; then
    echo "   → Generating VoiceMate.xcodeproj from Package.swift..."
    swift package generate-xcodeproj
    
    # Configure the generated xcodeproj for iOS app
    # Set deployment target and bundle ID
    /usr/libexec/PlistBuddy -c "Set :objects:PLACEHOLDER:buildSettings:IPHONEOS_DEPLOYMENT_TARGET 17.0" VoiceMate.xcodeproj/project.pbxproj 2>/dev/null || true
else
    echo "   → VoiceMate.xcodeproj already exists"
fi

echo "   ✅ VoiceMate ready"

cd ..

# ----- MemoEase -----
echo ""
echo "📱 [2/2] Setting up MemoEase..."

cd MemoEase

if [ ! -d "MemoEase.xcodeproj" ]; then
    echo "   → Generating MemoEase.xcodeproj from Package.swift..."
    swift package generate-xcodeproj
else
    echo "   → MemoEase.xcodeproj already exists"
fi

echo "   ✅ MemoEase ready"

cd ..

echo ""
echo "========================================"
echo "  ✅ All done! To open in Xcode:"
echo ""
echo "  VoiceMate:  open VoiceMate/VoiceMate.xcodeproj"
echo "  MemoEase:   open MemoEase/MemoEase.xcodeproj"
echo ""
echo "  Or open Package.swift directly:"
echo "  VoiceMate:  open VoiceMate/Package.swift"
echo "  MemoEase:   open MemoEase/Package.swift"
echo "========================================"
