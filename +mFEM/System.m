classdef System < handle
    %SYSTEM A class for automatic assembly of finite element equations.
    % This class allows the specification of the finite element equations
    % for matrices and vectors as strings, the assembly is handled
    % automatically.
    %
    % Example
    %   mesh = FEmesh()
    %   mesh.grid('Line2',0,1,10)
    %   mesh.init()
    %
    %   sys = System(mesh)
    %   sys.add_constant('k',10);
    %   sys.add_matrix('K','B''*k*B');
    %   K = sys.assemble('K');
    %   full(K)
    %
    % See Also FEMESH
    %
    %----------------------------------------------------------------------
    %  mFEM: An Object-Oriented MATLAB Finite Element Library
    %  Copyright (C) 2012 Andrew E Slaughter
    % 
    %  This program is free software: you can redistribute it and/or modify
    %  it under the terms of the GNU General Public License as published by
    %  the Free Software Foundation, either version 3 of the License, or
    %  (at your option) any later version.
    % 
    %  This program is distributed in the hope that it will be useful,
    %  but WITHOUT ANY WARRANTY; without even the implied warranty of
    %  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    %  GNU General Public License for more details.
    % 
    %  You should have received a copy of the GNU General Public License
    %  along with this program.  If not, see <http://www.gnu.org/licenses/>.
    %
    %  Contact: Andrew E Slaughter (andrew.e.slaughter@gmail.com)
    %----------------------------------------------------------------------
    
    properties(Access = public);
        time = 0;                   
    end
    
    properties (SetAccess = private, GetAccess = public)
        mesh = mFEM.FEmesh.empty;       % mesh object
        options = ...                   % struct of default user options
            struct('time', false);
    end
    
    properties (Access = private)
        mat;
        vec;
        const;
        func;
        list;
    end

    methods (Access = public)
        function obj = System(mesh, varargin)
            %SYSTEM Class constructor.    
            %
            % Syntax
            %   sys = System(mesh)
            %   sys = System(mesh, 'PropertyName', PropertyValue, ...)
            %
            % Description
            %   sys = System(mesh) creates a System object based on the
            %   supplied FEmesh object.
            %
            %   sys = System(mesh, 'PropertyName', PropertyValue) same as 
            %   above but allows the options to be changes
            %
            % System Properties Descriptions
            %   Time
            %       true | {false}
            %       A toggle for displaying the matrix and vector 
            %       assembly time.
            %   
            % See Also FEMESH
            
            % Parse the user-defined options
            obj.options = gatherUserOptions(obj.options, varargin{:});
            
            % Store the mesh object
            obj.mesh = mesh;
            
            obj.mat = mFEM.registry.MatrixKernelRegistry(mesh);
            obj.const = mFEM.registry.ConstantRegistry();
            obj.func = mFEM.registry.FuncRegistry();
            obj.vec = mFEM.registry.ConstantVectorRegistry(mesh);
            obj.list = {obj.mat, obj.const, obj.func, obj.vec};
        end
          
        function addConstant(obj, varargin)
            %ADDCONSTANT Adds constant(s) variables to the system.
            %
            % Syntax
            %   addConstant('ConstantName', ConstantValue, ...)
            %   addConstnat(..., '-add');
            %
            % Description
            %   addConstant('ConstantName', ConstantValue, ...) adds
            %   a single or multiple constants to the System, the
            %   'ConstantName' may be any string identifier and the value
            %   may be a numeric (scalar or matrix) or a string that may be
            %   evaluated using MATLAB's eval function.
            %
            %   addConstnat(..., '-add') operates the same as above but
            %   adds the values for variables that already exists, without
            %   this flag repeated values replace previously defined
            %   variables.
            %
            %
            % Examples
            %   sys.addConstant('k', 10, 'r', 2);
            %   sys.addCosntant('D', 'k^2');
            %   sys.addConstant('D', 10, '-add');
            obj.const.add(varargin{:});
        end
        
        function addFunc(obj, varargin)
            %ADDFUNC Adds function(s) variables to the system.
            %
            % Syntax
            %   addFunc('FunctionName', FunctionHandle, ...)
            %
            % Description
            %   add_Func('FunctionName', FunctionHandle, ...) adds
            %   function(s) to the System, the 'FunctionName' may be 
            %   any string identifier and the FunctionHandle may be a
            %   valid MATLAB function handle or character string, see
            %   details below.
            %
            % Description of Function Handle Input
            %   If the FunctionHandle property is a MATLAB function handle
            %   it must be in the following form:
            %
            %       FunctionHandle = @(elem, x, t) ...
            %       
            %   elem = An Element class object.
            %   x = The current position, where x(1) is the x-direction, 
            %   x(2) is the y-direction, and x(3) is the z-direction
            %   t = The current time, which is automatically passed to the
            %   function from the t variable of the System class itself.
            %
            % Description of Text Input
            %   It is also possible to specify a function as a text string
            %   such that the following is valid:
            %       fhandle = str2func(['@(elem,x,t)', <Text Input Here>]);
            %
            % Examples
            %   sys.add_function('k',@(elem,x,t) x(1)^2 + x(2)^2);
            %   sys.add_fucntion('p','x(1)^3');
            
            obj.func.add(varargin{:});
        end

        function addMatrix(obj, varargin)  
            %ADDMATRIX Create a sparse finite element matrix for assembly
            %
            % Syntax
            %   addMatrix('MatrixName', MatrixEqn, ...)
            %   addMatrix(..., 'PropertyName', PropertyValue)
            %
            % Description
            %   addMatrix('MatrixName', MatrixEqn) adds a matrix or
            %   matrices the associated equations for finite element
            %   assembly. The MatrixEqn is a string that is valid MATLAB
            %   (i.e., it works with the eval function) that gives the 
            %   integrands of the finite element equations at the element
            %   level. The variable N is predefined as the element shape 
            %   functions vector and B is pre-defined as grad(N). Any
            %   variable added with the ADDCONSTANT and ADDFUNC methods
            %   may be used.
            %
            %   addMatrix('MatrixName', MatrixEqn, 'PropertyName',
            %       PropertyValue) same as above, but the equation is 
            %   limited according to the supplied options. For example, the
            %   'Boundary' property limits the equation application to the 
            %   boundaries with the same id (see FEMESH.ADDBOUNDARY)
            %
            % ADDMATRIX Property Descriptions
            %   Boundary
            %       numeric
            %       Limits the application of the supplied equation to the 
            %       boundaries with the id, see FEMESH.ADDBOUNDARY
            %
            %   Subdomain
            %       numeric
            %       Limits the application of the supplied equation to the 
            %       elements on the subdomain, see FEMESH.ADDSUBDOMAIN
            %
            %   Component
            %       numeric
            %       Limits the application of the supplied equation to the
            %       specified component for vector unknowns.
            %
            % Examples
            %   sys.addMatrix('M','N''*N');
            %   sys.addMatrix('K','B''*B', 'Boundary', 1);
  
            obj.addMatrixPrivate('matrix', varargin{:});
        end

        function addVector(obj, varargin)  
            %ADDVECTOR Create a finite element vector for assembly
            %
            % Syntax
            %   addVector('VectorName', VectorEqn, ...)
            %   addVector('VectorName', NumericVector, ...)
            %   addVector(..., 'PropertyName', PropertyValue)
            %
            % Description
            %   addVector('VectorName', VectorEqn) adds vector(s) to the 
            %   the System for finite element assembly. The VectorEqn is a 
            %   string that is valid MATLAB (i.e., it works with the eval 
            %   function) that gives the  integrands of the finite element 
            %   equations at the element level. The variable N is 
            %   predefined as the element shape functions vector and B is 
            %   pre-defined as grad(N). Any variable added with the 
            %   ADDCONSTANT and ADDFUNC methods may be used.
            %
            %   addVector('VectorName', NumericVector) directly insert a
            %   numeric vector into the System.
            %
            %   addVector(..., 'PropertyName', PropertyValue) same as 
            %   above, but the equation is limited according to the 
            %   supplied options. For example, the 'Boundary' property 
            %   limits the equation application to the boundaries with the
            %   same id (see FEMESH.ADDBOUNDARY)
            %
            % ADDVECTOR Property Descriptions
            %   Boundary
            %       numeric
            %       Limits the application of the supplied equation to the 
            %       boundaries with the id, see FEMESH.ADDBOUNDARY
            %
            %   Subdomain
            %       numeric
            %       Limits the application of the supplied equation to the 
            %       elements on the subdomain, see FEMESH.ADDSUBDOMAIN
            %
            %   OverWrite
            %       true | {false}
            %       If true the vector is overwritten if the samename is
            %       encounter, otherwise the new vector is added to any
            %       existing.
            %
            %   Dof
            %       numeric vector
            %       Limits the application of the numeric input to specific
            %       dofs.
            %
            % Example
            %   sys.add_vector('f','N''*b'); % b is a constant

            obj.addMatrixPrivate('vector', varargin{:});
        end

        function addConstantVector(obj, varargin)
            %ADDCONSTANTVECTOR Create a finite element vector for assembly
            %
            % Syntax
            %   addConstantVector('VectorName', NumericVector, ...)
            %
            % Description
            %   addConstantVector('VectorName', VectorEqn) adds numeric 
            %   vector(s) to the System, this vector is then available in
            %   same fashion as traditional constants also the gradient may
            %   be used. See the example.
            %
            % ADDCONSTANTVECTOR Property Descriptions
            %   Boundary
            %       numeric
            %       Limits the application of the supplied equation to the 
            %       boundaries with the id, see FEMESH.ADDBOUNDARY
            %
            %   Subdomain
            %       numeric
            %       Limits the application of the supplied equation to the 
            %       elements on the subdomain, see FEMESH.ADDSUBDOMAIN
            %
            %   Component 
            %       numeric | char
            %       Limits the application of the supplied vector to the
            %       component of a vector value FEmesh. Value of of 1, 2,
            %       and 3 or 'x', 'y', and 'z' may be supplied.
            %
            %   OverWrite
            %       true | {false}
            %       If true the vector is overwritten if the same name is
            %       encounter, otherwise the new vector is added to any
            %       existing.
            %
            %   Dof
            %       numeric vector
            %       Limits the application of the numeric input to specific
            %       dofs.
            obj.vec.add(varargin{:});
        end
        
        function X = get(obj, name, varargin)
            %GET Returns the value for the specified name.
            %
            % Syntax
            %   X = get(name)
            %
            % Description
            %   X = get(name) returns the value of constant, function,
            %   vector, or matrix given the string name. The value returned
            %   depends on the type of object being returned:
            %       constant = scalar
            %       function = function handle
            %       vector = mFEM.Vector object
            %       matrix = mFEM.Matrix object
            
            % Loop through the storage structures and locate the variable
            kern = {};
            k = 1;
            for i = 1:length(obj.list);
                tmp = obj.list{i}.find(name);
                if ~isempty(tmp); 
                    kern{k} = tmp;
                    k = k + 1;
                end;
            end
            
            % Throw and error if the name was not found
            if isempty(kern);
                error('System:get', 'The entity with name %s was not found.', name);
            else
                if length(kern) == 1;
                    X = kern{1}.get(varargin{:});
                else
                    for i = 1:length(kern);
                        X{i} = kern{i}.get(varargin{:});
                    end
                end
            end   
        end
        
        function [TF, varargout] = exists(obj, name)
           %EXISTS Returns true if name exists as a type in System
           %
           % Syntax
           %    TF = exists(name)
           %    [TF, type] = exists(name)
           %
           % Description
           %    TF = exists(name) returns a true value if a constant,
           %    matrix, vector, or function exists in the System with the
           %    name given.           
           %
           %    [TF, type] = exists(name) same as above, but also returns
           %    the class type for registry containing the variable.

            % Loop through the storage structures and locate the variable
            TF = false(size(obj.list));
            k = 1;
            for i = 1:length(obj.list);
                idx = obj.list{i}.find(name, '-index');
                if ~isempty(idx); 
                    TF(i) = true;
                    if nargout == 2 && TF(i); 
                        varargout{1}{k} = class(obj.list{i});
                        k = k + 1;
                    end
                    %return; 
                end;
            end
        end
        
        function X = assemble(obj, name, varargin)
            %ASSEMBLE Assembles Matrix objects given by name
            %
            % Syntax
            %   X = assemble(name, 'PropertyName', PropertyValue, ...)
            %
            % Description
            %   X = assemble(name, 'PropertyName', PropertyValue, ...) 
            %   assembles the finite element matrix or vector. In the case 
            %   of a matrix the sparse matrix is returned, for vectors a 
            %   tradional MATLAB array is given. All property descriptions
            %   entered here overwrite those entered in the addMatrix or
            %   addVector methods.
            %
            % ASSEMBLE Property Descriptions
            %   Boundary
            %       numeric
            %       Limits the application of the supplied equation to the 
            %       boundaries with the id, see FEMESH.ADDBOUNDARY
            %
            %   Subdomain
            %       numeric
            %       Limits the application of the supplied equation to the 
            %       elements on the subdomain, see FEMESH.ADDSUBDOMAIN
            %
            %   Component
            %       numeric
            %       Limits the application of the supplied equation to the
            %       specified component for vector unknowns.
            
            % Extract the types with the given name
            [~, type] = obj.exists(name);
            
            for i = 1:length(type);
                if strcmp(type{i}, 'mFEM.registry.MatrixKernelRegistry');
                    if i == 1;
                        X = obj.mat.assemble(name, varargin{:});         
                    else
                        X = X + obj.mat.assemble(name, varargin{:});      
                    end
                elseif strcmp(type{i}, 'mFEM.registry.ConstantVectorRegistry');
                    if i == 1;
                        X = obj.vec.get(name, '-init');         
                    else
                        X = X + obj.vec.get(name, '-init');         
                    end
                else
                    error('System:assemble', 'Only variables added with addMatrix or addVector may be assembled');
                end
            end  
        end
    end 
    
    methods (Hidden = true, Access = private)    
        function addMatrixPrivate(obj, type, varargin)
            %ADDMATRIXPRIVATE Adds vector/matrix kernel registry
            %
            % Syntax
            %   addMatrixPrivate(type, ...)
            %
            % Description
            %   addMatrixPrivate(type, ...) operates exactly like addMatrix
            %   except that the first agrument determines if the
            %   MatrixKernel object is a 'vector' or 'matrix' type.
            
            % Define available options
            opt.boundary = [];
            opt.subdomain = [];
            opt.component = [];
            [opt, unknown] = gatherUserOptions(opt, varargin{:});

            % Location of last input flag
            n = length(unknown) - 1;
            
            % Loop through each name and store in the const property
            for i = 1:2:n;
                name = unknown{i};
                kern = unknown{i+1};
                
                if isa(kern, 'mFEM.kernels.base.MatrixKernel');
                    obj.mat.add(name, kern);
                    
                elseif ischar(kern);
                    kern = mFEM.kernels.AutoKernel(obj.mesh, name, kern,...
                        'ConstantRegistry', obj.const,...
                        'FuncRegistry', obj.func,...
                        'boundary', opt.boundary,...
                        'subdomain', opt.subdomain,...
                        'component', opt.component,...
                        'type', type);
                    obj.mat.add(name, kern);
                else
                    error('System:addMatrixPrivate', 'Input of type %s is not allowed, you must supply a valid character string or a MatrixKernel object', class(kern));
                end
            end  
        end
    end
end