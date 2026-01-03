#!/data/data/com.termux/files/usr/bin/bash

# GitHub Token验证脚本
# 用法：./check_github_tokens.sh

echo "======================================"
echo "      GitHub Token验证工具"
echo "======================================"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查jq是否安装
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}正在安装jq...${NC}"
    pkg install jq -y
    if [ $? -ne 0 ]; then
        echo -e "${RED}安装jq失败！请手动安装：pkg install jq${NC}"
        exit 1
    fi
fi

# 函数：测试单个token
test_token() {
    local token=$1
    local response
    local http_code
    
    echo -e "\n${YELLOW}测试Token: ${token:0:10}...${NC}"
    
    # 发送请求测试token
    response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: token $token" \
        -H "Accept: application/vnd.github.v3+json" \
        -X GET "https://api.github.com/user")
    
    # 分离HTTP状态码和响应体
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" == "200" ]; then
        # 解析响应
        username=$(echo "$response_body" | jq -r '.login // empty')
        name=$(echo "$response_body" | jq -r '.name // empty')
        email=$(echo "$response_body" | jq -r '.email // empty')
        
        if [ -n "$username" ]; then
            echo -e "${GREEN}✓ Token有效${NC}"
            echo "   用户名: $username"
            [ -n "$name" ] && echo "   姓名: $name"
            [ -n "$email" ] && echo "   邮箱: $email"
            return 0
        else
            echo -e "${RED}✗ Token无效（无法获取用户信息）${NC}"
            return 1
        fi
    elif [ "$http_code" == "401" ]; then
        echo -e "${RED}✗ Token无效或已过期${NC}"
        return 1
    elif [ "$http_code" == "403" ]; then
        # 检查速率限制
        rate_limit_response=$(curl -s -H "Authorization: token $token" \
            -H "Accept: application/vnd.github.v3+json" \
            -X GET "https://api.github.com/rate_limit")
        
        remaining=$(echo "$rate_limit_response" | jq -r '.resources.core.remaining // 0')
        limit=$(echo "$rate_limit_response" | jq -r '.resources.core.limit // 0')
        
        if [ "$remaining" -eq 0 ]; then
            echo -e "${RED}✗ Token有效但API速率限制已用尽${NC}"
            echo "   限制: $limit 请求/小时"
            return 0  # Token有效，只是被限流了
        else
            echo -e "${RED}✗ Token权限不足${NC}"
            return 1
        fi
    elif [ "$http_code" == "000" ]; then
        echo -e "${RED}✗ 网络连接失败${NC}"
        return 2
    else
        echo -e "${RED}✗ 未知错误 (HTTP $http_code)${NC}"
        echo "   响应: $response_body"
        return 1
    fi
}

# 主函数
main() {
    echo -e "\n${YELLOW}选择输入方式：${NC}"
    echo "1. 从文件读取Token（每行一个）"
    echo "2. 手动输入Token"
    echo "3. 从环境变量读取"
    read -p "请输入选项 (1-3): " choice
    
    tokens=()
    valid_tokens=()
    invalid_tokens=()
    
    case $choice in
        1)
            read -p "输入文件名（默认：tokens.txt）: " filename
            filename=${filename:-tokens.txt}
            
            if [ ! -f "$filename" ]; then
                echo -e "${RED}文件不存在：$filename${NC}"
                exit 1
            fi
            
            echo -e "\n从文件读取Token: $filename"
            while IFS= read -r token || [ -n "$token" ]; do
                token=$(echo "$token" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                [ -n "$token" ] && tokens+=("$token")
            done < "$filename"
            ;;
            
        2)
            echo -e "\n${YELLOW}手动输入Token（输入'end'结束）:${NC}"
            while true; do
                read -p "Token: " token
                [ "$token" == "end" ] && break
                token=$(echo "$token" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                [ -n "$token" ] && tokens+=("$token")
            done
            ;;
            
        3)
            echo -e "\n${YELLOW}从环境变量读取Token:${NC}"
            env_vars=$(env | grep -iE '(token|github|pat|secret)' | grep -v 'PATH')
            
            if [ -z "$env_vars" ]; then
                echo "未找到包含token、github、pat或secret的环境变量"
                exit 1
            fi
            
            echo "找到以下环境变量："
            echo "$env_vars"
            echo ""
            read -p "是否将这些值作为Token测试？(y/N): " confirm
            
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                while IFS= read -r line; do
                    token=$(echo "$line" | cut -d= -f2-)
                    token=$(echo "$token" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    [ -n "$token" ] && tokens+=("$token")
                done <<< "$env_vars"
            fi
            ;;
            
        *)
            echo -e "${RED}无效选项${NC}"
            exit 1
            ;;
    esac
    
    if [ ${#tokens[@]} -eq 0 ]; then
        echo -e "${RED}未找到任何Token${NC}"
        exit 1
    fi
    
    echo -e "\n${YELLOW}共找到 ${#tokens[@]} 个Token，开始测试...${NC}"
    echo "======================================"
    
    # 测试每个token
    for ((i=0; i<${#tokens[@]}; i++)); do
        token="${tokens[$i]}"
        echo -e "\n${YELLOW}[$((i+1))/${#tokens[@]}]${NC}"
        
        if test_token "$token"; then
            valid_tokens+=("$token")
        else
            invalid_tokens+=("$token")
        fi
        
        # 避免请求过快
        sleep 1
    done
    
    # 输出结果统计
    echo -e "\n${YELLOW}======================================${NC}"
    echo -e "${YELLOW}            测试结果统计             ${NC}"
    echo -e "${YELLOW}======================================${NC}"
    echo -e "${GREEN}有效Token: ${#valid_tokens[@]} 个${NC}"
    echo -e "${RED}无效Token: ${#invalid_tokens[@]} 个${NC}"
    echo -e "总计: ${#tokens[@]} 个"
    
    # 保存有效token到文件
    if [ ${#valid_tokens[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}保存有效Token到文件...${NC}"
        valid_file="valid_tokens_$(date +%Y%m%d_%H%M%S).txt"
        for token in "${valid_tokens[@]}"; do
            echo "$token" >> "$valid_file"
        done
        echo -e "${GREEN}有效Token已保存到: $valid_file${NC}"
    fi
    
    # 保存无效token到文件
    if [ ${#invalid_tokens[@]} -gt 0 ]; then
        invalid_file="invalid_tokens_$(date +%Y%m%d_%H%M%S).txt"
        for token in "${invalid_tokens[@]}"; do
            echo "$token" >> "$invalid_file"
        done
        echo -e "${RED}无效Token已保存到: $invalid_file${NC}"
    fi
}

# 运行主函数
main