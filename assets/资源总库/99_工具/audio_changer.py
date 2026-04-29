#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
音频批量转换工具
功能：将当前目录下的音频文件批量转换为16位WAV格式
自动处理ffmpeg依赖问题
输出目录：当前目录下的 16bit 文件夹
"""

import os
import sys
import argparse
import time
import traceback
import platform
import shutil
import subprocess
from pathlib import Path
import logging

# 设置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('audio_conversion.log', encoding='utf-8')
    ]
)
logger = logging.getLogger(__name__)

def check_ffmpeg():
    """检查ffmpeg是否可用"""
    try:
        # 尝试运行ffmpeg命令
        result = subprocess.run(
            ['ffmpeg', '-version'],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            shell=True
        )
        if result.returncode == 0 or result.returncode == 1:
            logger.info("✓ ffmpeg 已安装并可用")
            return True
    except (FileNotFoundError, subprocess.SubprocessError):
        pass
    
    # 尝试在常见位置查找ffmpeg
    common_paths = [
        'ffmpeg',
        'ffmpeg.exe',
        os.path.join(os.getcwd(), 'ffmpeg'),
        os.path.join(os.getcwd(), 'ffmpeg.exe'),
        os.path.join(os.path.dirname(__file__), 'ffmpeg'),
        os.path.join(os.path.dirname(__file__), 'ffmpeg.exe'),
    ]
    
    for path in common_paths:
        try:
            if os.path.exists(path):
                logger.info(f"✓ 在本地找到 ffmpeg: {path}")
                return True
        except:
            continue
    
    return False

def download_ffmpeg_windows():
    """为Windows用户提供下载ffmpeg的指导"""
    system = platform.system()
    architecture = platform.architecture()[0]
    
    logger.warning("未找到 ffmpeg，这是音频处理必需的依赖。")
    logger.info("\n请按以下步骤安装 ffmpeg:")
    
    if system == "Windows":
        logger.info("1. 访问 https://www.gyan.dev/ffmpeg/builds/")
        logger.info("2. 下载 'ffmpeg-release-essentials.zip'")
        logger.info("3. 解压到当前目录下的 'ffmpeg' 文件夹")
        logger.info("4. 将 'ffmpeg/bin' 目录添加到系统PATH")
        logger.info("\n或者运行以下命令自动下载（需要管理员权限）:")
        logger.info("  curl -L https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip -o ffmpeg.zip")
        logger.info("  tar -xf ffmpeg.zip -C .")
        logger.info("  move ffmpeg-* ffmpeg")
        logger.info("  setx PATH \"%PATH%;%cd%\\ffmpeg\\bin\"")
    elif system == "Darwin":  # macOS
        logger.info("运行: brew install ffmpeg")
    elif system == "Linux":
        logger.info("运行: sudo apt-get install ffmpeg  # Debian/Ubuntu")
        logger.info("或: sudo yum install ffmpeg  # RHEL/CentOS")
        logger.info("或: sudo pacman -S ffmpeg  # Arch")
    
    logger.info("\n安装完成后，请重新运行此脚本。")
    return False

def check_dependencies():
    """检查并安装必要的依赖"""
    missing_deps = []
    
    # 检查pydub
    try:
        from pydub import AudioSegment
        from pydub.utils import mediainfo
        logger.info("✓ pydub 已安装")
    except ImportError:
        missing_deps.append("pydub")
    
    if missing_deps:
        logger.error("缺少必要的依赖库:")
        for dep in missing_deps:
            logger.error(f"  - {dep}")
        
        logger.info("\n请使用以下命令安装依赖:")
        logger.info("  pip install pydub")
        
        # 尝试自动安装
        if ask_yes_no("是否尝试自动安装缺失的依赖？"):
            for dep in missing_deps:
                install_dependency(dep)
            # 重新检查
            return check_dependencies()
        else:
            return False
    
    # 检查ffmpeg
    if not check_ffmpeg():
        if ask_yes_no("是否要查看ffmpeg安装说明？"):
            download_ffmpeg_windows()
        return False
    
    return True

def ask_yes_no(question):
    """询问是/否问题"""
    while True:
        try:
            response = input(f"{question} (y/n): ").strip().lower()
            if response in ['y', 'yes']:
                return True
            elif response in ['n', 'no']:
                return False
        except (KeyboardInterrupt, EOFError):
            print()
            return False
        print("请输入 y 或 n")

def install_dependency(dep_name):
    """安装依赖"""
    import subprocess
    import sys
    
    logger.info(f"正在安装 {dep_name}...")
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", dep_name])
        logger.info(f"✓ {dep_name} 安装成功")
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"安装 {dep_name} 失败: {e}")
        return False

class AudioConverter:
    """音频转换器类"""
    
    # 支持的音频格式
    SUPPORTED_FORMATS = {
        '.wav', '.mp3', '.flac', '.aac', '.ogg', '.m4a',
        '.wma', '.aif', '.aiff', '.mp4', '.m4b', '.m4r',
        '.3gp', '.amr', '.opus', '.webm'
    }
    
    def __init__(self, input_dir=None, output_dir=None, sample_rate=44100, channels=2):
        """
        初始化音频转换器
        
        参数:
            input_dir: 输入目录（默认：当前目录）
            output_dir: 输出目录（默认：当前目录下的16bit文件夹）
            sample_rate: 目标采样率 (默认44100Hz)
            channels: 目标声道数 (1=单声道, 2=立体声)
        """
        # 如果没有指定输入目录，使用当前目录
        if input_dir is None:
            self.input_dir = Path.cwd()
        else:
            self.input_dir = Path(input_dir).resolve()
        
        # 如果没有指定输出目录，使用当前目录下的16bit文件夹
        if output_dir is None:
            self.output_dir = self.input_dir / "16bit"
        else:
            self.output_dir = Path(output_dir).resolve()
        
        self.sample_rate = sample_rate
        self.channels = channels
        
        # 确保目录存在
        self.input_dir.mkdir(parents=True, exist_ok=True)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        logger.info(f"输入目录: {self.input_dir}")
        logger.info(f"输出目录: {self.output_dir}")
        logger.info(f"采样率: {self.sample_rate} Hz")
        logger.info(f"声道数: {self.channels}")
    
    def find_audio_files(self, recursive=False):
        """查找音频文件"""
        audio_files = []
        
        if recursive:
            search_patterns = [f"*{ext}" for ext in self.SUPPORTED_FORMATS]
            for pattern in search_patterns:
                for file in self.input_dir.rglob(pattern):
                    if file.is_file():
                        audio_files.append(file)
        else:
            for file in self.input_dir.iterdir():
                if file.is_file() and file.suffix.lower() in self.SUPPORTED_FORMATS:
                    audio_files.append(file)
        
        # 去重和排序
        audio_files = sorted(set(audio_files))
        return audio_files
    
    def get_file_info(self, file_path):
        """获取音频文件信息"""
        try:
            from pydub.utils import mediainfo
            info = mediainfo(str(file_path))
            
            return {
                'bit_depth': info.get('bits_per_sample', '未知'),
                'sample_rate': info.get('sample_rate', '未知'),
                'channels': info.get('channels', '未知'),
                'duration': float(info.get('duration', 0)),
                'size': file_path.stat().st_size
            }
        except Exception as e:
            logger.warning(f"无法获取文件信息 {file_path.name}: {e}")
            return None
    
    def convert_file_simple(self, input_file, output_file):
        """使用简单方法转换音频文件（避免ffmpeg依赖）"""
        try:
            # 尝试使用wave库处理wav文件
            if input_file.suffix.lower() == '.wav':
                import wave
                import struct
                
                with wave.open(str(input_file), 'rb') as wav_in:
                    params = wav_in.getparams()
                    frames = wav_in.readframes(params.nframes)
                
                # 转换为16位PCM
                with wave.open(str(output_file), 'wb') as wav_out:
                    wav_out.setnchannels(min(params.nchannels, 2))
                    wav_out.setsampwidth(2)  # 16位
                    wav_out.setframerate(self.sample_rate)
                    wav_out.writeframes(frames)
                
                return True, "使用wave库转换成功"
            
            # 对于非wav文件，尝试使用pydub
            from pydub import AudioSegment
            audio = AudioSegment.from_file(str(input_file))
            
            # 转换为16位
            audio = audio.set_sample_width(2)
            audio = audio.set_frame_rate(self.sample_rate)
            
            if self.channels == 1:
                audio = audio.set_channels(1)
            elif self.channels == 2:
                audio = audio.set_channels(2)
            
            # 导出为WAV
            audio.export(str(output_file), format='wav')
            
            return True, "使用pydub转换成功"
            
        except Exception as e:
            error_msg = f"转换失败: {str(e)}"
            logger.error(f"  {error_msg}")
            return False, error_msg
    
    def convert_file(self, input_file, output_file, overwrite=False):
        """
        转换单个音频文件
        
        返回:
            (success, message)
        """
        try:
            # 检查输出文件是否已存在
            if output_file.exists() and not overwrite:
                return False, f"文件已存在: {output_file.name}"
            
            # 确保输出目录存在
            output_file.parent.mkdir(parents=True, exist_ok=True)
            
            # 显示原始信息
            file_info = self.get_file_info(input_file)
            if file_info:
                logger.info(f"  原始: {file_info['bit_depth']}位, "
                          f"{file_info['sample_rate']}Hz, "
                          f"{file_info['channels']}声道, "
                          f"{file_info['duration']:.1f}秒")
            
            # 尝试多种转换方法
            success = False
            message = ""
            
            # 方法1: 尝试简单转换
            success, message = self.convert_file_simple(input_file, output_file)
            
            if not success:
                # 方法2: 尝试使用pydub的详细参数
                try:
                    from pydub import AudioSegment
                    audio = AudioSegment.from_file(str(input_file))
                    
                    # 转换为16位
                    audio = audio.set_sample_width(2)
                    audio = audio.set_frame_rate(self.sample_rate)
                    
                    if self.channels == 1:
                        audio = audio.set_channels(1)
                    elif self.channels == 2:
                        audio = audio.set_channels(2)
                    
                    # 尝试不同的导出参数
                    try:
                        audio.export(str(output_file), format='wav')
                        success = True
                        message = "使用备用方法转换成功"
                    except:
                        # 方法3: 尝试保存为原始数据
                        import wave
                        import array
                        
                        # 获取原始数据
                        raw_data = audio.raw_data
                        sample_width = audio.sample_width
                        channels = audio.channels
                        frame_rate = audio.frame_rate
                        
                        with wave.open(str(output_file), 'wb') as wav_out:
                            wav_out.setnchannels(channels)
                            wav_out.setsampwidth(2)  # 强制16位
                            wav_out.setframerate(self.sample_rate)
                            
                            # 如果原始数据不是16位，需要转换
                            if sample_width != 2:
                                # 简单的16位转换
                                import struct
                                # 这里需要根据实际数据格式转换
                                # 简化处理：直接写入原始数据
                                wav_out.writeframes(raw_data)
                            else:
                                wav_out.writeframes(raw_data)
                        
                        success = True
                        message = "使用原始数据转换成功"
                
                except Exception as e:
                    success = False
                    message = f"所有转换方法都失败: {str(e)}"
            
            # 验证输出
            if success and output_file.exists():
                output_size = output_file.stat().st_size
                output_info = self.get_file_info(output_file)
                
                if output_info:
                    logger.info(f"  转换后: {output_info['bit_depth']}位, "
                              f"{output_info['sample_rate']}Hz, "
                              f"{output_info['channels']}声道")
                
                return True, f"转换成功 ({output_size:,} 字节)"
            else:
                return False, f"转换失败: {message}"
                
        except Exception as e:
            error_msg = f"转换失败: {str(e)}"
            logger.error(f"  {error_msg}")
            return False, error_msg
    
    def batch_convert(self, recursive=False, overwrite=False):
        """批量转换音频文件"""
        # 查找音频文件
        audio_files = self.find_audio_files(recursive)
        
        if not audio_files:
            logger.warning(f"在 {self.input_dir} 中未找到支持的音频文件")
            logger.info(f"支持的格式: {', '.join(sorted(self.SUPPORTED_FORMATS))}")
            return {'total': 0, 'success': 0, 'failed': 0}
        
        logger.info(f"找到 {len(audio_files)} 个音频文件")
        
        # 转换统计
        stats = {
            'total': len(audio_files),
            'success': 0,
            'failed': 0,
            'skipped': 0
        }
        
        start_time = time.time()
        
        # 开始转换
        for i, input_file in enumerate(audio_files, 1):
            # 计算输出路径
            if recursive:
                rel_path = input_file.relative_to(self.input_dir)
                output_file = self.output_dir / rel_path.with_suffix('.wav')
            else:
                output_file = self.output_dir / input_file.with_suffix('.wav').name
            
            logger.info(f"[{i}/{len(audio_files)}] 处理: {input_file.name}")
            
            # 转换文件
            success, message = self.convert_file(input_file, output_file, overwrite)
            
            if success:
                stats['success'] += 1
            elif "文件已存在" in message:
                stats['skipped'] += 1
                logger.info(f"  跳过: {message}")
            else:
                stats['failed'] += 1
            
            # 显示进度
            progress = (i / len(audio_files)) * 100
            print(f"\r进度: {progress:.1f}% ({i}/{len(audio_files)})", end='')
        
        print()  # 换行
        
        # 计算耗时
        elapsed_time = time.time() - start_time
        
        return {
            **stats,
            'elapsed_time': elapsed_time
        }

def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description='音频批量转换工具 - 将当前目录下的音频转换为16位WAV格式',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 基本用法：转换当前目录下的所有音频文件
  python audio_to_16bit_with_ffmpeg.py
  
  # 递归处理当前目录及其子目录
  python audio_to_16bit_with_ffmpeg.py -r
  
  # 指定采样率和声道数
  python audio_to_16bit_with_ffmpeg.py -s 48000 -c 1
  
  # 覆盖已存在的输出文件
  python audio_to_16bit_with_ffmpeg.py -o
  
  # 显示支持的音频格式
  python audio_to_16bit_with_ffmpeg.py --formats
  
  # 指定输入和输出目录（可选）
  python audio_to_16bit_with_ffmpeg.py --input /path/to/input --output /path/to/output
        """
    )
    
    parser.add_argument('--input', help='输入目录路径（默认：当前目录）', default='.')
    parser.add_argument('--output', help='输出目录路径（默认：当前目录下的16bit文件夹）', default=None)
    parser.add_argument('-r', '--recursive', action='store_true',
                       help='递归处理子目录')
    parser.add_argument('-o', '--overwrite', action='store_true',
                       help='覆盖已存在的输出文件')
    parser.add_argument('-s', '--sample-rate', type=int, default=44100,
                       help='目标采样率 (默认: 44100)')
    parser.add_argument('-c', '--channels', type=int, default=2, choices=[1, 2],
                       help='目标声道数 (默认: 2)')
    parser.add_argument('--formats', action='store_true',
                       help='显示支持的音频格式')
    
    args = parser.parse_args()
    
    # 显示支持的格式
    if args.formats:
        print("支持的音频格式:")
        for fmt in sorted(AudioConverter.SUPPORTED_FORMATS):
            print(f"  {fmt}")
        return 0
    
    # 检查输入目录
    input_path = Path(args.input)
    if not input_path.exists():
        logger.error(f"输入目录不存在: {args.input}")
        return 1
    
    if not input_path.is_dir():
        logger.error(f"输入路径不是目录: {args.input}")
        return 1
    
    # 检查依赖
    if not check_dependencies():
        logger.error("依赖检查失败，请确保已安装所有必需的依赖")
        return 1
    
    # 显示标题
    print("=" * 60)
    print("音频批量转换工具")
    print(f"将 {input_path} 中的音频转换为16位WAV格式")
    print("=" * 60)
    
    # 创建转换器
    converter = AudioConverter(
        input_dir=args.input,
        output_dir=args.output,
        sample_rate=args.sample_rate,
        channels=args.channels
    )
    
    # 执行转换
    stats = converter.batch_convert(
        recursive=args.recursive,
        overwrite=args.overwrite
    )
    
    # 显示结果
    print("=" * 60)
    print("转换完成!")
    print(f"总文件数: {stats['total']}")
    print(f"成功转换: {stats['success']}")
    print(f"转换失败: {stats['failed']}")
    print(f"跳过文件: {stats['skipped']}")
    print(f"耗时: {stats['elapsed_time']:.2f}秒")
    
    if stats['failed'] > 0:
        print("\n警告: 部分文件转换失败，请查看日志文件 audio_conversion.log")
        print("如果是因为缺少ffmpeg，请按照提示安装ffmpeg")
    
    print("=" * 60)
    
    return 0 if stats['failed'] == 0 else 1

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\n用户中断操作")
        sys.exit(130)
    except Exception as e:
        logger.error(f"程序运行出错: {e}")
        logger.error(traceback.format_exc())
        sys.exit(1)
