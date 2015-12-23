classdef SoftmaxLayer < OperateLayer
    methods
        function obj = SoftmaxLayer(option)
            if nargin == 0
                super_args{1} = struct();
            else if nargin == 1
                    super_args{1} = option;
                end
            end
            obj = obj@OperateLayer(super_args{:});
            obj.initialOption(super_args{:});
            obj.initial();
        end
        
        function [output,length] = fprop(obj,input,length)
            obj.length = length;
            for i = 1 : obj.length
                obj.input{1,i} = input{1,i};
                obj.input{2,i} = input{2,i};
                obj.output{2,i} = input{2,i};
                obj.output{1,i} = bsxfun(@plus,obj.W.context * obj.input{1,i},obj.B.context);
                obj.output{1,i} = exp(bsxfun(@minus,obj.output{1,i},max(obj.output{1,i},[],1)));
                obj.output{1,i} = bsxfun(@rdivide,obj.output{1,i},sum(obj.output{1,i},1));
                obj.output{1,i} = bsxfun(@times,obj.output{1,i},obj.output{2,i});
            end
            output = obj.output;
        end
        
        function output = fprop_step(obj,input,i)
            obj.length = i;
            obj.input{1,i} = input{1,1};
            obj.input{2,i} = input{2,1};
            obj.output{2,i} = input{2,1};
            obj.output{1,i} = bsxfun(@plus,obj.W.context * obj.input{1,i},obj.B.context);
            obj.output{1,i} = exp(bsxfun(@minus,obj.output{1,i},max(obj.output{1,i},[],1)));
            obj.output{1,i} = bsxfun(@rdivide,obj.output{1,i},sum(obj.output{1,i},1));
            obj.output{1,i} = bsxfun(@times,obj.output{1,i},obj.output{2,i});
            output{1,1} = obj.output{1,i};
            output{2,1} = obj.output{2,i};
        end
        
        function cost = getCost(obj,target)
            cost = 0;
            for i = 1 : obj.length
                index = (obj.output{2,i} > 0);
                temp_target = target{1,i};
                temp_output = 1 : size(obj.output{1,i},2);
                cost_index = sub2ind(size(obj.output{1,i}),temp_target(index),temp_output(index));
                cost = cost + sum((- log(obj.output{1,i}(cost_index)))) ./ length(temp_output);
            end
        end
        
        function grad_input = bprop(obj,target)
            for i = 1 : obj.length
                index = (obj.output{2,i} > 0);
                temp_target = target{1,i};
                temp_output = 1 : size(obj.output{1,i},2);
                cost_index = sub2ind(size(obj.output{1,i}),temp_target(index),temp_output(index));
                obj.grad_output{1,i} = obj.output{1,i};
                obj.grad_output{1,i}(cost_index) = obj.grad_output{1,i}(cost_index) - 1;
                obj.grad_input{1,i} = obj.W.context' * obj.grad_output{1,i};
                obj.grad_W.context = obj.grad_W.context + obj.grad_output{1,i} * (obj.input{1,i})' ./ size(obj.input{1,i},2);
                obj.grad_B.context = obj.grad_B.context + mean(obj.grad_output{1,i},2);
            end
            grad_input = obj.grad_input;
        end
        %% the functions below this line are used in the above functions or some functions are just defined for the gradient check;
        function checkGrad(obj)
            seqLen = 20;
            batchSize = 10;
            input = cell([2,seqLen]);
            target = cell([1,seqLen]);
            mask = ones(seqLen,batchSize);
            truncate = randi(seqLen - 1,1,batchSize);
            for i = 1 : batchSize - 1
                mask( 1 : truncate(1,i),i) = 0;
            end
            mask(:,batchSize) = 1;
            for i = 1 : seqLen
                input{2,i} = mask(i,:);
                input{1,i} = bsxfun(@times,randn([obj.input_dim,batchSize]),mask(i,:));
                target{1,i} = randi(obj.hidden_dim,1,batchSize) .* mask(i,:);
            end
            epislon = 10 ^ (-7);
            
            W = obj.W.context;
            B = obj.B.context;
            obj.fprop(input,size(input,2));
            obj.bprop(target);
            grad_input = obj.grad_input;
            grad_W = obj.grad_W.context;
            grad_B = obj.grad_B.context;
            numeric_grad_W = zeros(size(W));
            numeric_grad_B = zeros(size(grad_B));
            numeric_grad_input = cell(size(grad_input));
            for i = 1 : size(numeric_grad_input,2)
                numeric_grad_input{1,i} = zeros(size(grad_input{1,i}));
            end
            %% the W parameter check
            for n = 1 : size(W,1)
                for m = 1 : size(W,2)
                    obj.W.context = W;
                    obj.W.context(n,m) = obj.W.context(n,m) + epislon;
                    obj.fprop(input,size(input,2));
                    cost_1 = obj.getCost(target);
                    
                    obj.W.context = W;
                    obj.W.context(n,m) = obj.W.context(n,m) - epislon;
                    obj.fprop(input,size(input,2));
                    cost_2 = obj.getCost(target);
                    
                    numeric_grad_W(n,m) = (cost_1 - cost_2) ./ (2 * epislon);
                end
            end
            norm_diff = norm(numeric_grad_W(:) - grad_W(:)) ./ norm(numeric_grad_W(:) + grad_W(:));
            if obj.debug
                disp([numeric_grad_W(:),grad_W(:)]);
            end
            disp(['the W parameter check is ' , num2str(norm_diff)])
            %% the B parameter check
            for n = 1 : size(B,1)
                for m = 1 : size(B,2)
                    obj.B.context = B;
                    obj.B.context(n,m) = obj.B.context(n,m) + epislon;
                    obj.fprop(input,size(input,2));
                    cost_1 = obj.getCost(target);
                    
                    obj.B.context = B;
                    obj.B.context(n,m) = obj.B.context(n,m) - epislon;
                    obj.fprop(input,size(input,2));
                    cost_2 = obj.getCost(target);
                    
                    numeric_grad_B(n,m) = (cost_1 - cost_2) ./ (2 * epislon);
                end
            end
            norm_diff = norm(numeric_grad_B(:) - grad_B(:)) ./ norm(numeric_grad_B(:) + grad_B(:));
            if obj.debug
                disp([numeric_grad_B(:),grad_B(:)]);
            end
            disp(['the B parameter check is ' , num2str(norm_diff)])
            %% check the gradient of input data
            for t = 1 : seqLen
                temp = input{1,t};
                for i = 1 : size(temp,1)
                    for j = 1 : size(temp,2)
                        if input{2,t}(1,j) == 0
                            continue;
                        end
                        temp_input = input;
                        temp = temp_input{1,t};
                        temp(i,j) = temp(i,j) + epislon;
                        temp_input{1,t} = temp;
                        obj.fprop(temp_input,size(temp_input,2));
                        cost_1 = obj.getCost(target);

                        temp_input = input;
                        temp = temp_input{1,t};
                        temp(i,j) = temp(i,j) - epislon;
                        temp_input{1,t} = temp;
                        obj.fprop(temp_input,size(temp_input,2));
                        cost_2 = obj.getCost(target);
                        numeric_grad_input{1,t}(i,j) = (cost_1 - cost_2) ./ (2 * epislon);
                    end
                end
                norm_diff = norm(numeric_grad_input{1,t}(:) - grad_input{1,t}(:) ./ batchSize) ./ norm(numeric_grad_input{1,t}(:) + grad_input{1,t}(:) ./ batchSize);
                if obj.debug
                    disp([numeric_grad_input{1,t}(:),grad_input{1,t}(:)]);
                end
                disp([num2str(t),' : the check of input gradient is ' , num2str(norm_diff)])
            end
        end
    end
end