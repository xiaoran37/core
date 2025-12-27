#!/data/data/com.termux/files/usr/bin/python3
import os
import re
from pathlib import Path
import sys

def extract_channel_names_from_m3u(file_content):
    """从M3U格式内容中提取频道名称"""
    names = []
    lines = file_content.strip().split('\n')
    
    for line in lines:
        line = line.strip()
        # 跳过空行
        if not line:
            continue
        
        # 保留所有包含 #genre# 的行
        if '#genre#' in line.lower():
            names.append(line)
            continue
        
        # 跳过其他注释行
        if line.startswith('#'):
            continue
        
        # 尝试分割逗号，格式为：名称,链接
        if ',' in line:
            parts = line.split(',', 1)  # 只分割第一个逗号
            name = parts[0].strip()
            # 过滤掉可能是链接的部分
            if name and not name.startswith(('http://', 'https://', 'rtmp://', 'rtsp://')):
                # 清理名称中的特殊字符
                name = re.sub(r'[,#、，]', '', name)
                if name:
                    names.append(name)
    
    return names

def process_txt_files_recursive(root_folder, output_file="channel_names.txt"):
    """递归处理所有txt文件并保存结果"""
    root_path = Path(root_folder)
    
    if not root_path.exists():
        print(f"❌ 错误：文件夹不存在 - {root_path}")
        return None
    
    # 递归查找所有txt文件
    txt_files = list(root_path.rglob("*.txt"))
    
    if not txt_files:
        print(f"⚠️ 在 {root_path} 及其子文件夹中未找到txt文件")
        return None
    
    print(f"📂 找到 {len(txt_files)} 个txt文件")
    print("=" * 60)
    
    # 收集所有频道名称
    all_names = []
    processed_files = 0
    
    for txt_file in txt_files:
        processed_files += 1
        # 计算相对路径，方便查看
        rel_path = txt_file.relative_to(root_path)
        print(f"🔍 处理 [{processed_files}/{len(txt_files)}]: {rel_path}")
        
        try:
            # 尝试UTF-8编码
            with open(txt_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            names = extract_channel_names_from_m3u(content)
            if names:
                print(f"   ✅ 提取到 {len(names)} 个项目")
                all_names.extend(names)
            else:
                print(f"   ⚠️  未提取到项目")
            
        except UnicodeDecodeError:
            try:
                # 尝试GBK编码
                with open(txt_file, 'r', encoding='gbk') as f:
                    content = f.read()
                names = extract_channel_names_from_m3u(content)
                if names:
                    print(f"   ✅ 提取到 {len(names)} 个项目 (GBK编码)")
                    all_names.extend(names)
                else:
                    print(f"   ⚠️  未提取到项目 (GBK编码)")
            except Exception as e:
                print(f"   ❌ 解码失败: {e}")
        except Exception as e:
            print(f"   ❌ 处理失败: {e}")
    
    print("=" * 60)
    
    if not all_names:
        print("⚠️ 未提取到任何项目")
        return None
    
    # 去重并保持顺序
    seen = set()
    unique_names = []
    for name in all_names:
        if name not in seen:
            seen.add(name)
            unique_names.append(name)
    
    print(f"📊 统计结果:")
    print(f"   📁 扫描文件夹: {root_path}")
    print(f"   📄 处理文件数: {len(txt_files)}")
    print(f"   🔤 提取项目总数: {len(all_names)}")
    print(f"   🎯 去重后数量: {len(unique_names)}")
    print(f"   🗑️  重复项数量: {len(all_names) - len(unique_names)}")
    
    # 保存到文件
    output_path = root_path / output_file
    with open(output_path, 'w', encoding='utf-8') as f:
        for name in unique_names:
            f.write(name + '\n')
    
    print(f"\n✅ 结果已保存到: {output_path}")
    
    # 显示部分结果
    if unique_names:
        print("\n📺 提取结果示例:")
        print("-" * 40)
        for i, name in enumerate(unique_names[:20], 1):
            if '#genre#' in name.lower():
                print(f"  {i:3d}. 📁 {name}")
            else:
                print(f"  {i:3d}. 📺 {name}")
        
        if len(unique_names) > 20:
            print(f"  ... 还有 {len(unique_names)-20} 个")
    
    # 生成统计报告
    generate_statistics_report(root_path, unique_names, len(txt_files))
    
    return output_path

def generate_statistics_report(root_path, unique_names, file_count):
    """生成统计报告"""
    report_path = root_path / "extract_report.txt"
    
    # 统计分类数量和频道数量
    category_count = sum(1 for name in unique_names if '#genre#' in name.lower())
    channel_count = len(unique_names) - category_count
    
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write("=" * 60 + "\n")
        f.write("📊 频道名称提取统计报告\n")
        f.write("=" * 60 + "\n")
        f.write(f"提取时间: {get_current_time()}\n")
        f.write(f"扫描目录: {root_path}\n")
        f.write(f"处理文件数: {file_count}\n")
        f.write(f"提取总项目数: {len(unique_names)}\n")
        f.write(f"📁 分类数量: {category_count}\n")
        f.write(f"📺 频道数量: {channel_count}\n")
        f.write("=" * 60 + "\n\n")
        
        f.write("📁 分类列表:\n")
        f.write("-" * 40 + "\n")
        for i, name in enumerate(unique_names, 1):
            if '#genre#' in name.lower():
                f.write(f"{i:4d}. 📁 {name}\n")
        
        f.write("\n📺 频道列表:\n")
        f.write("-" * 40 + "\n")
        for i, name in enumerate(unique_names, 1):
            if '#genre#' not in name.lower():
                f.write(f"{i:4d}. 📺 {name}\n")
    
    print(f"📋 统计报告: {report_path}")

def get_current_time():
    """获取当前时间"""
    from datetime import datetime
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def main():
    """主函数"""
    # 设置工作目录
    target_folder = "/storage/emulated/0/1314/assets/subscribe/source/b"
    
    print("=" * 60)
    print("📁 频道名称提取工具 (递归版)")
    print(f"📂 目标文件夹: {target_folder}")
    print("=" * 60)
    
    # 处理文件
    result_file = process_txt_files_recursive(target_folder)
    
    if result_file:
        print("\n🎉 处理完成!")
        
        # 显示文件信息
        if os.path.exists(result_file):
            file_size = os.path.getsize(result_file)
            print(f"📄 输出文件: {result_file}")
            print(f"📏 文件大小: {file_size:,} 字节")
            print(f"🔤 行数统计: {sum(1 for _ in open(result_file, 'r', encoding='utf-8'))} 行")
    else:
        print("\n⚠️  处理完成，但未生成结果文件")
    
    print("=" * 60)

if __name__ == "__main__":
    main()