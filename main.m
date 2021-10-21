%% Initialization
clear ; close all; clc

%% ImportData
% 初始化变量。
filename = '.\Pipeline.csv';
delimiter = ',';
startRow = 2;

% 将数据列作为文本读取:
% 有关详细信息，请参阅 TEXTSCAN 文档。
formatSpec = '%q%q%q%q%q%q%[^\n\r]';

% 打开文本文件。
fileID = fopen(filename,'r');

% 根据格式读取数据列。
% 该调用基于生成此代码所用的文件的结构。如果其他文件出现错误，请尝试通过导入工具重新生成代码。
dataArray = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'TextType', 'string', 'HeaderLines' ,startRow-1, 'ReturnOnError', false, 'EndOfLine', '\r\n');

% 关闭文本文件。
fclose(fileID);

% 将包含数值文本的列内容转换为数值。
% 将非数值文本替换为 NaN。
raw = repmat({''},length(dataArray{1}),length(dataArray)-1);
for col=1:length(dataArray)-1
    raw(1:length(dataArray{col}),col) = mat2cell(dataArray{col}, ones(length(dataArray{col}), 1));
end
numericData = NaN(size(dataArray{1},1),size(dataArray,2));

for col=[1,2,6]
    % 将输入元胞数组中的文本转换为数值。已将非数值文本替换为 NaN。
    rawData = dataArray{col};
    for row=1:size(rawData, 1)
        % 创建正则表达式以检测并删除非数值前缀和后缀。
        regexstr = '(?<prefix>.*?)(?<numbers>([-]*(\d+[\,]*)+[\.]{0,1}\d*[eEdD]{0,1}[-+]*\d*[i]{0,1})|([-]*(\d+[\,]*)*[\.]{1,1}\d+[eEdD]{0,1}[-+]*\d*[i]{0,1}))(?<suffix>.*)';
        try
            result = regexp(rawData(row), regexstr, 'names');
            numbers = result.numbers;
            
            % 在非千位位置中检测到逗号。
            invalidThousandsSeparator = false;
            if numbers.contains(',')
                thousandsRegExp = '^\d+?(\,\d{3})*\.{0,1}\d*$';
                if isempty(regexp(numbers, thousandsRegExp, 'once'))
                    numbers = NaN;
                    invalidThousandsSeparator = true;
                end
            end
            % 将数值文本转换为数值。
            if ~invalidThousandsSeparator
                numbers = textscan(char(strrep(numbers, ',', '')), '%f');
                numericData(row, col) = numbers{1};
                raw{row, col} = numbers{1};
            end
        catch
            raw{row, col} = rawData{row};
        end
    end
end


% 将数据拆分为数值和字符串列。
rawNumericColumns = raw(:, [1,2,6]);
rawStringColumns = string(raw(:, [3,4,5]));


% 将非数值元胞替换为 NaN
R = cellfun(@(x) ~isnumeric(x) && ~islogical(x),rawNumericColumns); % 查找非数值元胞
rawNumericColumns(R) = {NaN}; % 替换非数值元胞

% 创建输出变量
PipelineData = raw;
% 清除临时变量
clearvars filename delimiter startRow formatSpec fileID dataArray ans raw col numericData rawData row regexstr result numbers invalidThousandsSeparator thousandsRegExp rawNumericColumns rawStringColumns R;

%% Data preprocessing
DETECT_EQUIP_NO = cell2mat(PipelineData(:,1));
POSITION_NO = cell2mat(PipelineData(:,2));

BARCODE = string(PipelineData(:,3));

LOAD_CURRENT = string(PipelineData(:,4));
PF = string(PipelineData(:,5));

AVE_ERR = cell2mat(PipelineData(:,6));

ITEM_NO = zeros(size(LOAD_CURRENT));
for i = 1:length(LOAD_CURRENT)
    if LOAD_CURRENT(i) == '05' && PF(i) == '01'
        ITEM_NO(i) = 1;
    elseif LOAD_CURRENT(i) == '05' && PF(i) == '07'
        ITEM_NO(i) = 2;
    elseif LOAD_CURRENT(i) == '07' && PF(i) == '07'
        ITEM_NO(i) = 3;
    elseif LOAD_CURRENT(i) == '08' && PF(i) == '01'
        ITEM_NO(i) = 4;
    elseif LOAD_CURRENT(i) == '08' && PF(i) == '07'
        ITEM_NO(i) = 5;
    elseif LOAD_CURRENT(i) == '09' && PF(i) == '01'
        ITEM_NO(i) = 6;
    elseif LOAD_CURRENT(i) == '00' && PF(i) == '01'
        ITEM_NO(i) = 7;
    elseif LOAD_CURRENT(i) == '00' && PF(i) == '07'
        ITEM_NO(i) = 8;
    elseif LOAD_CURRENT(i) == '01' && PF(i) == '01'
        ITEM_NO(i) = 9;
    elseif LOAD_CURRENT(i) == '01' && PF(i) == '07'
        ITEM_NO(i) = 10;  
    else
        ITEM_NO(i) = 0; 
    end
end

%% Data classification

dataset = zeros(20,60,3);
num = zeros(12000,1);

for i = 1:20
    for j = 1:60
        % feature extraction
        a = DETECT_EQUIP_NO == i; 
        b = POSITION_NO == j; 
        for k = 1:10
            c = ITEM_NO == k;
            index = find((a&b&c)==1);
            error = AVE_ERR(index);

            num(((i-1)*60+j-1)*10+k) = length(index);

            mu = mean(error);
            sigma = std(error);
            skew = skewness(error);
            kurt = kurtosis(error);


            dataset(i,j,k) = mu;
            dataset(i,j,k+10) = sigma;
            dataset(i,j,k+20) = skew;
            dataset(i,j,k+30) = kurt;
        end
    end
end

%% Data visualization

% X1 = zeros(60,2);
% X1(:,1) = dataset(1,:,1);
% X1(:,2) = dataset(1,:,2);
% 
% X2 = zeros(60,2);
% X2(:,1) = dataset(2,:,1);
% X2(:,2) = dataset(2,:,2);

X = dataset;
figure;

axis([-0.1 0.1 -0.1 0.1 -0.1 0.1]);
grid;
xlabel('item1 (error%)');
ylabel('item3 (error%)');
zlabel('item4 (error%)');

hold on
palette = hsv(20);

for i = 1:20
    fprintf('Program paused. Press enter to continue.\n');
    pause;
    scatter3(X(i, :, 1), X(i, :, 7), X(i, :, 8), 15, palette(i,:));
    
end



hold off











