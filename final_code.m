% JPEG 2000 Inspired Codec Evaluation
% Leonor Castelo - s257446
% PIPELINE:
%   T -> Q -> Arithmetic Coding -> Q^{-1} -> T^{-1}
% EVALUATION:
%   1. Code length using arithmetic coding
%   2. Cross-entropy estimate (H1 adaptive context model)
%   3. Comparison between arithmetic code length and entropy estimate
%   4. Objective quality: PSNR + MSE
%   5. Subjective quality: reconstructed images
%   6. Rate-distortion performance

clear; close all; clc;
%%Parameters
num_levels   = 3; %number of DWT decomposition levels 
delta_values = [1, 4, 8, 16, 32, 64, 128]; %Quantization step sizes to evaluate
img = double(imread('lenna.tif')); %Load test image as double
[H, W] = size(img);
fprintf('Image: %d x %d pixels | Uncompressed = %d bpp\n\n', H, W, 8);
psnr_all       = zeros(size(delta_values));
mse_all        = zeros(size(delta_values));
bpp_arith_all  = zeros(size(delta_values));  %Bits per pixel from arithmetic coding 
bpp_h1_all     = zeros(size(delta_values));  %Bits per pixel from H1 entropy estimate
cf_arith_all   = zeros(size(delta_values));  %Compression factor from arithmetic coding 
cf_h1_all      = zeros(size(delta_values));  %Compression factor from H1 estimate

%% MAIN LOOP

%iterate over each quantization step size
for k = 1:numel(delta_values)
    delta = delta_values(k);
    fprintf('delta = %d\n', delta);
    % BLOCK T: WAVELET TRANSFORM
    %Decompose the image into multi-resolution subbands (LL, LH, HL, HH)
    [subbands, bookkeeping] = dwt2d_forward(img, num_levels);
    % BLOCK Q: QUANTIZATION
    %Applies deadzone scalar quantization to each subband
    %Step sizes are scaled per level and subband type
    [subbands_q, stepSizes] = quantize_subbands(subbands, delta, num_levels);
    % ENTROPY CODING: ARITHMETIC CODING
    %Encodes all quantized subbands into a single bitstream
    bitstream = arithmetic_encode_subbands(subbands_q, num_levels);
    bits_arith = length(bitstream);
    bpp_arith_all(k) = bits_arith / (H * W);
    cf_arith_all(k) = 8 / bpp_arith_all(k);
    % CROSS-ENTROPY ESTIMATION (ORDER-1 MODEL)
    %Estimates the theoretical bit cost using a first-order context model
    %This serves as a lower bound on what a better entropycould achieve
    bits_h1 = estimate_entropy_adaptive(subbands_q, num_levels);
    bpp_h1_all(k) = bits_h1 / (H * W);
    cf_h1_all(k) = 8 / bpp_h1_all(k);
    % COMPARISON: Arithmetic arithmetic vs. entropy estimate
    redundancy_bits = bits_arith - bits_h1;
    redundancy_pct = 100 * redundancy_bits / bits_arith;
    fprintf('Arithmetic coding:\n');
    fprintf('Bits=%10d\n', bits_arith);
    fprintf('bpp=%10.4f\n', bpp_arith_all(k));
    fprintf('CF=%10.2fx\n\n', cf_arith_all(k));
    fprintf('Cross-entropy estimate (H1):\n');
    fprintf('Bits= %10.0f\n', bits_h1);
    fprintf('bpp= %10.4f\n', bpp_h1_all(k));
    fprintf('CF= %10.2fx\n\n', cf_h1_all(k));
    fprintf('Comparison:\n');
    fprintf('Redundancy = %.0f bits (%.2f%%)\n\n', redundancy_bits, redundancy_pct);
    % BLOCK Q^{-1}: DEQUANTIZATION
    %reconstruct aproximate subband coefficients from quantized indices
    subbands_rec =dequantize_subbands(subbands_q, stepSizes, num_levels);
    % BLOCK T^{-1}: INVERSE WAVELET TRANSFORM
    %Reconstructs the image from the dequantized subbands 
    img_rec = dwt2d_inverse(subbands_rec, bookkeeping, num_levels);
    % OBJECTIVE QUALITY
    mse_all(k) = mean((img(:) - img_rec(:)).^2);
    psnr_all(k) = compute_psnr(img, img_rec);
    fprintf('Quality:\n');
    fprintf('  MSE  = %.4f\n', mse_all(k));
    fprintf('  PSNR = %.2f dB\n\n', psnr_all(k));
    % SUBJECTIVE QUALITY: display selected reconstruction

    if any(delta == [1 4 8 16 32 64 128])
        figure('Name', sprintf('delta=%d | PSNR=%.2f dB', delta, psnr_all(k)));
        subplot(1,2,1);
        imshow(uint8(img));
        title('Original');
        subplot(1,2,2);
        imshow(uint8(img_rec));
        title(sprintf('Reconstructed (delta=%d)', delta));
    end
end
%Reconstruction of the images in a single figure 
figure('Name','All Reconstructions');
num_imgs = numel(delta_values);
for k = 1:num_imgs
    delta = delta_values(k);
    [subbands, bookkeeping] = dwt2d_forward(img, num_levels);
    [subbands_q, stepSizes] = quantize_subbands(subbands, delta, num_levels);
    subbands_rec = dequantize_subbands(subbands_q, stepSizes, num_levels);
    img_rec = dwt2d_inverse(subbands_rec, bookkeeping, num_levels);
    subplot(2,4,k);
    imshow(uint8(img_rec));
    title(sprintf('\\delta=%d\nPSNR=%.1f dB', ...
        delta, psnr_all(k)));
end
subplot(2,4,8);
imshow(uint8(img));
title('Original');
% RATE-DISTORTION CURVE
%Plots PSNR vs bits per pixel for both arithmetic coding and H1 estimate
figure('Name','Rate-Distortion');
plot(bpp_arith_all, psnr_all, 'b-o','LineWidth',2, 'MarkerSize',8);
hold on;
plot(bpp_h1_all, psnr_all, 'r-s', 'LineWidth',2, 'MarkerSize',8);
%Annotate each point with its delta values 
for k = 1:numel(delta_values)
    text(bpp_arith_all(k), psnr_all(k)+0.7, sprintf('\\delta=%d', delta_values(k)),  'FontSize',7, 'HorizontalAlignment','center');
    text(bpp_h1_all(k), psnr_all(k)-1.0, sprintf('\\delta=%d', delta_values(k)), 'FontSize',7, 'HorizontalAlignment','center', 'Color','r');
end
xline(1.5, '--k', 'DCI reference (1.5 bpp)');
yline(45, '--m', '45 dB');
xlabel('Rate (bits/pixel)');
ylabel('PSNR (dB)');
title('Rate-Distortion Performance');
legend('Arithmetic coding', 'Cross-entropy estimate H1','Location','southwest');
grid on;
fprintf('\n');
fprintf('SUMMARY TABLE\n');
fprintf('%-8s %-12s %-12s %-12s %-12s %-10s\n', 'delta', 'bpp(arith)', 'bpp(H1)', 'CF(arith)', 'CF(H1)', 'PSNR');
fprintf('%s\n', repmat('-',1,70));
for k = 1:numel(delta_values)
    fprintf('%-8d %-12.4f %-12.4f %-12.2f %-12.2f %-10.2f\n', ...
        delta_values(k), bpp_arith_all(k), bpp_h1_all(k), cf_arith_all(k), cf_h1_all(k), psnr_all(k));
end

%% LOCAL FUNCTIONS

%% DWT FORWARD
%Performs a 2D separable Discrete Wavelet Transform using the bior4.4
%At each level, the LL subband is further decomposed, producing a multi-resolution pyramid of subbands (LH, HL, HH per level + final LL) 
function [subbands, bookkeeping] = dwt2d_forward(img, num_levels)
    dwtmode('per');        %Periodic extension to avoid border artefacts
    filter = 'bior4.4';    % Biorthogonal 4.4 wavelet (used in JPEG 2000)
    [LO_D, HI_D] = wfilters(filter, 'd');   %Decomposition filters (lowpasss & highpass)
    
    bookkeeping.sizes = cell(num_levels,1); %Store sizes for correct inverse transform 
    bookkeeping.num_levels = num_levels;    
    subbands.LH = cell(num_levels,1);
    subbands.HL = cell(num_levels,1);
    subbands.HH = cell(num_levels,1);
    current = img;
    for j = 1:num_levels
        [rows, cols] = size(current);
        bookkeeping.sizes{j} = [rows cols];

        %Horizontal 1D DWT
        L     = zeros(rows, cols/2);
        H_arr = zeros(rows, cols/2);
        for r = 1:rows
            [L(r,:), H_arr(r,:)] = dwt(current(r,:), LO_D, HI_D);
        end

        %vertical 1D DWT
        LL= zeros(rows/2, cols/2);
        LH= zeros(rows/2, cols/2);
        HL_arr = zeros(rows/2, cols/2);
        HH= zeros(rows/2, cols/2);
        for c = 1:cols/2
            [LL(:,c), LH(:,c)] = dwt(L(:,c), LO_D, HI_D);          %Low columns
            [HL_arr(:,c), HH(:,c)] = dwt(H_arr(:,c), LO_D, HI_D);  %High columns
        end
        %Store detail subbands
        %pass LL down to the next level
        subbands.LH{j} = LH;
        subbands.HL{j} = HL_arr;
        subbands.HH{j} = HH;
        current = LL;
    end
    subbands.LL = current;
end

% DWT INVERSE
%Reconstruct the image by applying the inverse DWT level by level
function img_rec = dwt2d_inverse(subbands, bookkeeping, num_levels)
    filter = 'bior4.4';
    current = subbands.LL;
    for j = num_levels:-1:1
        sz = bookkeeping.sizes{j};
        current = idwt2(current, subbands.LH{j}, subbands.HL{j}, subbands.HH{j}, filter, sz);
    end
    img_rec = current;
end

%% QUANTIZATION
% deadzone scalar quantizer: coefficients within [-delta, delta] map to zero 
function q = deadzone_quantize(x, delta)
    q = sign(x) .* floor(abs(x) ./ delta);
end

% dequantizer: maps quantized indices back to mid-point reconstruction values
function x_hat = deadzone_dequantize(q, delta)
    x_hat = zeros(size(q));
    mask = (q ~= 0);
    x_hat(mask) = sign(q(mask)) .* (abs(q(mask)) + 0.5) .* delta;
end


% applies quantization to all subbands with level-adaptive step sizes 
% Higher decomposition levels (coarser) use larger step sizes,
% and HH subbands (diagonal) use 1.5x the step of LH/HL to reduce
% diagonal artefacts (less visually important)
function [subbands_q, stepSizes] = quantize_subbands(subbands, delta_base, num_levels)
    stepSizes.LL = delta_base * 0.5;  % Finer quantization for the approximation subband
    for j = 1:num_levels
        scale = 2^(j-1);              % Scale increases with decomposition level
        stepSizes.LH{j} = delta_base * scale;
        stepSizes.HL{j} = delta_base * scale;
        stepSizes.HH{j} = delta_base * scale * 1.5;
    end
    subbands_q.LL = deadzone_quantize(subbands.LL, stepSizes.LL);
    for j = 1:num_levels
        subbands_q.LH{j} = deadzone_quantize(subbands.LH{j}, stepSizes.LH{j});
        subbands_q.HL{j} = deadzone_quantize(subbands.HL{j}, stepSizes.HL{j});
        subbands_q.HH{j} = deadzone_quantize(subbands.HH{j}, stepSizes.HH{j});
    end
end

% applies quantization to all subbands using the stored step sizes
function subbands_rec = dequantize_subbands(subbands_q, stepSizes, num_levels)
    subbands_rec.LL = deadzone_dequantize(subbands_q.LL, stepSizes.LL);
    for j = 1:num_levels
        subbands_rec.LH{j} = deadzone_dequantize(subbands_q.LH{j}, stepSizes.LH{j});
        subbands_rec.HL{j} = deadzone_dequantize(subbands_q.HL{j}, stepSizes.HL{j});
        subbands_rec.HH{j} = deadzone_dequantize(subbands_q.HH{j}, stepSizes.HH{j});
    end
end

%% ARITHMETIC CODING

% Concatenates all quantized subband coefficients into a single sequence, re-indexes symbols to be positive integers, appends an symbol and encodes using an adaptive arithmetic coder

function bitstream = arithmetic_encode_subbands(subbands_q, num_levels)
    seq = [subbands_q.LL(:)];
    for j = 1:num_levels
        seq = [seq;
               subbands_q.LH{j}(:);
               subbands_q.HL{j}(:);
               subbands_q.HH{j}(:)];
    end
    seq = int32(seq);
    minSym = min(seq);
    seq = seq - minSym + 1;    % Shift symbols to start at 1
    EOF_symbol = max(seq) + 1; % Reserve a symbol to signal end-of-stream
    seq = [seq; EOF_symbol];
    alphabet_size = double(max(seq));
    bitstream = arithmetic_encoder(seq, alphabet_size);
end


%Adaptive arithmetic coding using a 32-bit integer precision
% Implements the standard interval scaling with E3 (pending bits) scaling to handle intervals that straddle the midpoint without underflow
% Symbol probabilities are updated after each symbol (adaptive model)
function bitstream = arithmetic_encoder(data, alphabet_size)
    precision = 32;
    MAX_RANGE = 2^precision - 1;
    HALF      = 2^(precision-1);
    QUARTER   = 2^(precision-2);
    THREE_QTR = 3 * QUARTER;
    low  = uint64(0);
    high = uint64(MAX_RANGE);
    pending_bits = 0;  %counts bits deferred due to E3 scaling 
    freq = ones(1, alphabet_size);  % Initial uniform frequency counts (Laplace smoothing)
    bitstream = [];
    for k = 1:length(data)
        symbol = data(k);
        cumfreq = [0 cumsum(freq)];
        total = cumfreq(end);
        %narrow the intervalo to the sub-interval of the current symbol
        range = double(high - low + 1);
        high = low + floor(range * cumfreq(symbol+1) / total) - 1;
        low  = low + floor(range * cumfreq(symbol) / total);
        %Output bits and rescale while the intervak lies in one half or
        %converges toward the midpoint (E1, E2 E3 conditions) 
        while true
            if high < HALF
                %interval in lower half: output 0
                [bitstream, pending_bits] = output_bit(bitstream, 0, pending_bits);
            elseif low >= HALF
                %interval in upper half: output 1
                [bitstream, pending_bits] = output_bit(bitstream, 1, pending_bits);
                low  = low - HALF;
                high = high - HALF;
            elseif low >= QUARTER && high < THREE_QTR
                %E3: intervalstraddles mid-point
                pending_bits = pending_bits + 1;
                low  = low - QUARTER;
                high = high - QUARTER;
            else
                break;
            end
            low  = low * 2;
            high = high * 2 + 1;
        end
        %update frequency count for adaptive model
        freq(symbol) = freq(symbol) + 1;
        %Halve counts if total grows too large
        if sum(freq) > 1e5
            freq = ceil(freq / 2);
        end
    end
    %flush remainin bits: output the final distinguishing bit
    pending_bits = pending_bits + 1;
    if low < QUARTER
        [bitstream, pending_bits] = output_bit(bitstream, 0, pending_bits);
    else
        [bitstream, pending_bits] = output_bit(bitstream, 1, pending_bits);
    end
end


%Ouputs one bit following by  'pending_bits' complementary bits
function [bitstream, pending_bits] = output_bit(bitstream, bit, pending_bits)
    bitstream(end+1) = bit;
    for i = 1:pending_bits
        bitstream(end+1) = 1 - bit; %complementary bits resolve pending uncertainty
    end
    pending_bits = 0;
end

%% ENTROPY ESTIMATION
%Estimates the theorical number of bits needed to code the quantized
%subbands using a first-order context model (H1)

function total_bits_h1 = estimate_entropy_adaptive(subbands_q, num_levels)
    total_bits_h1 = 0;
    total_bits_h1 = total_bits_h1 + subband_h1(subbands_q.LL);
    for j = 1:num_levels
        total_bits_h1 = total_bits_h1 + subband_h1(subbands_q.LH{j});
        total_bits_h1 = total_bits_h1 + subband_h1(subbands_q.HL{j});
        total_bits_h1 = total_bits_h1 + subband_h1(subbands_q.HH{j});
    end
end


% computes the H1 cross-entropy estimate for a single subband
%uses Laplace smoothing (alpha =1) to avoid zero-probability issues
%context c=0: previous coefficient was negative; c=1 non negative
function bits_h1 = subband_h1(sb)
    vals = double(sb(:));
    alpha = 1;
    %binary context: 1 if previous value >=0 else 0
    ctx_bin = double([0; vals(1:end-1)] >= 0);
    L_total = 0;
    for c = 0:1
        vals_c = vals(ctx_bin == c); %coefficients under context c
        if isempty(vals_c)
            continue;
        end
        symb = unique(vals_c);
        N_c = numel(vals_c);
        A = numel(symb);
        for s = 1:A
            n_ic = sum(vals_c == symb(s));
            %smoothed probability estimate
            p_hat = (n_ic + alpha) / (N_c + alpha * A);
            L_total = L_total + n_ic * (-log2(p_hat)); %cross-entropy contribution
        end
    end
    bits_h1 = L_total;
end

%% PSNR
% Computes Peak Signal-to-Noise Ratio between original and reconstructed image.
function psnr = compute_psnr(original, reconstructed)
    mse = mean((original(:) - reconstructed(:)).^2);
    if mse == 0
        psnr = Inf;
    else
        psnr = 10 * log10(255^2 / mse);
    end
end








