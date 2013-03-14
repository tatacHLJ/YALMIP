function [model,keptvariables,infeasible] = eliminatevariables(model,varindex,value)

keptvariables = 1:length(model.c);

% The first set of equalities are just used when the model is linear in the
% parametric variables, hence we delete them 
%model.F_struc(1:length(varindex),:) = [];
%model.K.f = model.K.f - length(varindex);

%newmonomtable = model.monomtable;
%rmvmonoms = newmonomtable(:,varindex);
%newmonomtable(:,varindex) = 0;

rmvmonoms = model.rmvmonoms;
newmonomtable = model.newmonomtable;

%ss = repmat(value(:)',size(rmvmonoms,1),1);
%aux = ss.^rmvmonoms;
%monomvalue = prod(aux,2);

%[ii,jj] = find(rmvmonoms);
%aux = rmvmonoms*0+1;
%indexx = sub2ind(size(rmvmonoms),ii,jj);
aux = model.precalc.aux;
if ~isempty(model.precalc.jj1)
    z = value(model.precalc.jj1).^rmvmonoms(model.precalc.index1);
    aux(model.precalc.index1) = z;
end
if ~isempty(model.precalc.jj2)
    aux(model.precalc.index2) = value(model.precalc.jj2);
end
monomvalue = prod(aux,2);

%removethese = find(~any(newmonomtable,2));
%keepingthese = find(any(newmonomtable,2));

removethese = model.removethese;
keepingthese = model.keepingthese;

value = monomvalue(removethese);
%monomgain = monomvalue;monomgain(removethese) = [];
monomgain = monomvalue(keepingthese);

if ~isempty(model.F_struc)
    model.F_struc(:,1) = model.F_struc(:,1)+model.F_struc(:,1+removethese)*value;
    model.F_struc(:,1+removethese) = [];
    model.F_struc = model.F_struc*diag(sparse([1;monomgain]));
end
infeasible = 0;
if model.K.f > 0
    candidates = find(sum(abs(model.F_struc(1:model.K.f,2:end)),2) == 0);
    if ~isempty(candidates)
        % infeasibles = find(model.F_struc(candidates,1)~=0);
        if find(model.F_struc(candidates,1)~=0,1)%;~isempty(infeasibles)
            infeasible = 1;
            return
        else
            model.F_struc(candidates,:) = [];
            model.K.f = model.K.f - length(candidates);
        end
    end
end
if model.K.l > 0
    candidates = find(sum(abs(model.F_struc(model.K.f + (1:model.K.l),2:end)),2) == 0);  
    if ~isempty(candidates)
       %infeasibles = find(model.F_struc(model.K.f + candidates,1)<0);
         if find(model.F_struc(model.K.f + candidates,1)<0,1) 
             infeasible = 1;
             return
         else
             model.F_struc(model.K.f + candidates,:) = [];
             model.K.l = model.K.l - length(candidates);
         end

%         infeasibles = find(model.F_struc(model.K.f + candidates,1)<0);
%         if ~isempty(infeasibles)          
%             infeasible = 1;
%             return
%         else
%             model.F_struc(model.K.f + candidates,:) = [];
%             model.K.l = model.K.l - length(candidates);
%         end
    end
end
if model.K.q(1) > 0
    removeqs = [];
    removeRows = [];
    top = model.K.f + model.K.l + 1;  
    F_struc = model.F_struc(top:top+sum(model.K.q)-1,:);   
    top = 1;
    if all(any(F_struc(:,2:end),2))
        % There is still something on every row in all SOCPs, we don't have
        % to search for silly SOCPS ||0|| <= constant
    else
        for i = 1:length(model.K.q)
            rows = top:top+model.K.q(i)-1;
            v = F_struc(rows,:);
            if nnz(v(:,2:end))==0
                if norm(v(2:end,1)) > v(1,1)
                    infeasible = 1;
                    return
                else
                    removeqs = [removeqs;i];
                    removeRows = [removeRows;model.K.f+model.K.l+rows];
                end
            end
            top = top + model.K.q(i);
        end
        model.K.q(removeqs)=[];
        model.F_struc(removeRows,:)=[];
        if isempty(model.K.q)
            model.K.q = 0;
        end
    end
end
if model.K.s(1) > 0
    % This code cannot occur yet, so untested
    % Nonlinear semidefinite program with parameter
    top = model.K.f + model.K.l + sum(model.K.q) + 1;
    removeqs = [];
    removeRows = [];
    for i = 1:length(model.K.q)
        n = model.K.s(i);
        rows = top:top+n^2-1;
        v = model.F_struc(rows,:);
        if nnz(v(:,2:end))==0
            [~,p] = chol(reshape(v(:,1),n,n));
            if p
                infeasible = 1;
                return
            else
                removeqs = [removeqs;i];
                removeRows = [removeRows;rows];
            end
        end
        top = top + n^2;
    end
    model.K.s(removeqs)=[];
    model.F_struc(removeRows,:)=[];
    if isempty(model.K.q)
        model.K.q = 0;
    end
end

model.f = model.f + model.c(removethese)'*value;

model.c(removethese)=[];
if nnz(model.Q)>0
    model.c = model.c + 2*model.Q(keepingthese,removethese)*value;
end
model.Q(removethese,:) = [];
model.Q(:,removethese) = [];

model.c = model.c.*monomgain;
keptvariables(removethese) = [];

model.lb(removethese)=[];
model.ub(removethese)=[];

newmonomtable(:,removethese) = [];
newmonomtable(removethese,:) = [];

if ~isequal(newmonomtable,model.precalc.newmonomtable)%~isempty(removethese)
    skipped = [];
    alreadyAdded = zeros(1,size(newmonomtable,1));
    % R2012b
   % [ii,jj,kk] = unique(newmonomtable,'rows','stable');
    [ii,jj,kk] = unique(newmonomtable*gen_rand_hash(0,size(newmonomtable,2),1),'rows','stable');
   % [ii1,jj1,kk1] = unique(newmonomtable,'rows','stable');
    S = sparse(kk,1:length(kk),1);
    skipped = setdiff(1:length(kk),jj);
    model.precalc.S = S;
    model.precalc.skipped = skipped;
    model.precalc.newmonomtable = newmonomtable;
    model.precalc.blkOneS = blkdiag(1,S');
else
    S = model.precalc.S;
    skipped = model.precalc.skipped;
end
model.c = S*model.c;
%model.F_struc2 = [model.F_struc(:,1) (S*model.F_struc(:,2:end)')'];
model.F_struc = model.F_struc*model.precalc.blkOneS;%blkdiag(1,S');
%norm(model.F_struc-model.F_struc2)
if 0
    for i  = 1:size(newmonomtable,1)
        if ~alreadyAdded(i)
            this = newmonomtable(i,:);
            j = findrows(newmonomtable(i+1:1:end,:),this);
            if ~isempty(j)
                j = j + i;
                % j = setdiff(j,skipped);
                % if ~isempty(j)
                model.c(i) = model.c(i) + sum(model.c(j));
                model.F_struc(:,i+1) = model.F_struc(:,i+1) + sum(model.F_struc(:,j+1),2);
                skipped = unique([skipped j(:)']);
                alreadyAdded(j)=1;
                %  end
            end
        end
    end
    model.c(skipped) = [];   
    model.F_struc(:,1+skipped) = [];
end
model.lb(skipped) = [];
model.ub(skipped) = [];
newmonomtable(skipped,:) = [];
newmonomtable(:,skipped) = [];
model.Q(:,skipped)=[];
model.Q(skipped,:)=[];
keptvariables(skipped) = [];

model.monomtable = newmonomtable;
model = compressModel(model);

x0wasempty = isempty(model.x0);
model.x0 = zeros(length(model.c),1);

% Try to reduce to QP
[model,keptvariables,newmonomtable] = setupQuadratics(model,keptvariables,newmonomtable);

if x0wasempty
    model.x0 = [];
end

% Remap indicies
if ~isempty(model.integer_variables)
    temp=ismember(keptvariables,model.integer_variables);
    model.integer_variables = find(temp);  
end
if ~isempty(model.binary_variables)
    temp=ismember(keptvariables,model.binary_variables);
    model.binary_variables = find(temp);    
end
if ~isempty(model.semicont_variables)
   temp=ismember(keptvariables,model.semicont_variables);
    model.semicont_variables = find(temp);  
end

function model = compressModel(model)
model.variabletype = zeros(size(model.monomtable,1),1)';
nonlinear = sum(model.monomtable,2)~=1 | sum(model.monomtable~=0,2)~=1;
if ~isempty(nonlinear)
    model.variabletype(nonlinear) = 3;
    quadratic = sum(model.monomtable,2)==2;
    model.variabletype(quadratic) = 2;
    bilinear = max(model.monomtable,[],2)<=1;
    model.variabletype(bilinear & quadratic) = 1;
    sigmonial = any(0>model.monomtable,2) | any(model.monomtable-fix(model.monomtable),2);
    model.variabletype(sigmonial) = 4;
end




function [model,keptvariables,newmonomtable] = setupQuadratics(model,keptvariables,newmonomtable);
if any(model.variabletype) & all(model.variabletype <= 2)
    monomials = find(model.variabletype);
    if nnz(model.F_struc(:,1+monomials))==0
        if all(isinf(model.lb(monomials)))
            if all(isinf(model.ub(monomials)))
                for k = monomials(:)'
                    i = find(model.monomtable(k,:));
                    if model.variabletype(k)==1
                        model.Q(i(1),i(2)) = model.Q(i(1),i(2)) + model.c(k)/2;
                        model.Q(i(2),i(1)) = model.Q(i(1),i(2));
                    else
                        model.Q(i,i) = model.Q(i,i) + model.c(k);
                    end
                end
                model.c(monomials)=[];
                model.F_struc(:,1+monomials) = [];
                model.lb(monomials) = [];
                model.ub(monomials) = [];
                newmonomtable(monomials,:) = [];
                newmonomtable(:,monomials) = [];
                model.monomtable = newmonomtable;
                model.Q(:,monomials) = [];
                model.Q(monomials,:) = [];
                model.x0(monomials) = [];
                model.variabletype(monomials)=[];                
                keptvariables(monomials) = [];                
            end
        end 
    end
end
