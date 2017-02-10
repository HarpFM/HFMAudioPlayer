source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '9.0'

inhibit_all_warnings!

use_frameworks!

workspace 'HFMAudioPlayer.xcworkspace'

target 'HFMAudioPlayer' do
    project 'HFMAudioPlayer/HFMAudioPlayer.xcodeproj'
    podspec :path => 'HFMAudioPlayer.podspec'
    
    target 'HFMAudioPlayerTests' do
        project 'HFMAudioPlayer/HFMAudioPlayer.xcodeproj'
        inherit! :search_paths
        # Pods for testing
    end
end