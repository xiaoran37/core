#!/data/data/com.termux/files/usr/bin/bash

# 基础URL
BASE_URL="https://raw.githubusercontent.com/xiaoran29/core/refs/heads/main/"
LOCAL_PATH="/storage/emulated/0/1314"
OUTPUT_FILE="/storage/emulated/0/1314/core_links.txt"

echo "遍历本地仓库: $LOCAL_PATH"
echo "基础URL: $BASE_URL"
echo "输出到: $OUTPUT_FILE"

# 清空输出文件
> "$OUTPUT_FILE"

# 进入本地仓库目录
cd "$LOCAL_PATH" || { echo "目录不存在: $LOCAL_PATH"; exit 1; }

# 遍历所有txt文件并拼接URL
find . -name "*.txt" -type f | while read file; do
    # 移除开头的./
    rel_path="${file#./}"
    # 拼接完整URL
    full_url="${BASE_URL}${rel_path}"
    # 写入文件
    echo "$full_url" >> "$OUTPUT_FILE"
    echo "生成: $full_url"
done

echo ""
echo "====================================="
echo "完成！链接已保存到: $OUTPUT_FILE"
echo "文件数量: $(wc -l < "$OUTPUT_FILE")"
echo "====================================="