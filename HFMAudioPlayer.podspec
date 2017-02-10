Pod::Spec.new do |s|
    
    s.name             = 'HFMAudioPlayer'
    s.version          = '0.1.0'
    
    s.author           = { 'Brian Drelling' => 'brian@harp.fm' }
    s.homepage         = 'https://github.com/bdrelling/HFMAudioPlayer'
    s.license          = 'MIT'
    s.platform         = :ios, '9.0'
    s.social_media_url = 'http://twitter.com/HarpFM'
    s.source           = { :git => 'https://github.com/bdrelling/HFMAudioPlayer.git', :tag => s.version }
    s.summary          = 'Allows agnostic AudioPlayer control of both local and streaming audio files.'

    s.source_files = 'HFMAudioPlayer/HFMAudioPlayer/**/*.swift'

end
