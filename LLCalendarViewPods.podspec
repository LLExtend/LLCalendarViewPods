

Pod::Spec.new do |spec|

  #库名称
  spec.name         = "LLCalendarViewPods"

  #版本号
  spec.version      = "0.1.0"

  #库简短介绍
  spec.summary      = "LLCalendarViewPods 日历控件"

  #开源库描述
  spec.description  = <<-DESC
                    简单的日历控件
                   DESC

  #开源库地址，或者是博客、社交地址等
  spec.homepage     = "https://github.com/LLExtend/LLCalendarViewPods"

  #开源协议
  spec.license      = { :type => "MIT", :file => "FILE_LICENSE" }

  #开源库作者
  spec.author             = { "zhaoyulong" => "1432039807@qq.com" }

  #社交网址
  spec.social_media_url   = "https://juejin.im/user/5a52fbee6fb9a01c9064b627"

  #指定支持的平台和版本，不写则默认支持所有的平台，如果支持多个平台，则使用下面的deployment_target定义
  spec.platform     = :ios, "9.0"

  #开源库最低支持
  spec.ios.deployment_target = '9.0'

  #开源库GitHub的路径与tag值，GitHub路径后必须有.git,tag实际就是上面的版本
  spec.source       = { :git => "https://github.com/LLExtend/LLCalendarViewPods.git", :tag => "0.1.0" }

  #源库资源文件
  spec.source_files  = "LLCalendarView/Classes", "LLCalendarView/Classes/**/*.{h,m}"

  #依赖系统库
  spec.frameworks = "Foundation", "UIKit"

  #是否支持arc
  spec.requires_arc = true

end
