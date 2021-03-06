classdef Tri6 < mFEM.elements.base.Element
    %Tri6 6-node triangle element
    % 
    %        xi2  
    %         ^
    %         |
    %                     xi3 = 1 - xi2 - xi2
    %         3
    %         | \  
    %         |  \
    %         |   \
    %     (3) 6    5  (2)      
    %         |     \           
    %         |      \    
    %         1---4---2  ---> xi1
    %            (1) 
    %
    % http://mmc.geofisica.unam.mx/Bibliografia/Matematicas/EDP/MetodosNumericos/FEM/IFEM.Ch24.pdf
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
    
    % Define the inherited abstract properties
    properties (Constant, GetAccess = public)
        n_sides = 3;                        % no. of sides
        side_dof = [1,2,4; 2,3,5; 3,1,6];   % define the side dofs (ordered as associated with Line3 element)
        side_type = 'Line3';                % 3-node line element for sides
        quad = ...                          % 4-point triangular quadrature 
            mFEM.Gauss('order',4,'type','tri'); 
    end
    
    % Define the Tri6 constructor
    methods
        function obj = Tri6(id, nodes, varargin)
           % Class constructor; calls base class constructor
           
           % Test that nodes is sized correctly
           if ~all(size(nodes) == [3,2]) && ~all(size(nodes) == [6,2]);
                error('Tri6:Tri6','Nodes not specified correctly; expected a [3x2] or [6x2] array, but recieved a [%dx%d] array.', size(nodes,1), size(nodes,2));
           end
           
           % Special case when only nodes 1,2,3 are given
           if all(size(nodes) == [3,2])
               nodes(4,:) = mean(nodes(1:2,:));
               nodes(5,:) = mean(nodes(2:3,:));
               nodes(6,:) = mean(nodes([3,1],:));
           end

           % Call the base class constructor
           obj = obj@mFEM.elements.base.Element(id, nodes, varargin{:});
           
           % Set the node plotting order (this is only needed because the
           % nodes are not in order)
           obj.node_plot_order = [1,4,2,5,3,6]; 
        end
    end
    
    % Define the inherited abstract methods (protected)
    methods (Access = protected)    
        
        function J = jacobian(obj, in)
            % Define the Jacobain
            x = obj.nodes(:,1);
            y = obj.nodes(:,2);
            xi1 = in(1); xi2 = in(2);
            xi3 = 1 - xi1 - xi2;
            
            Jx1 = x(1)*(4*xi1-1) + 4*(x(4)*xi2 + x(6)*xi3);
            Jx2 = x(2)*(4*xi2-1) + 4*(x(5)*xi3 + x(4)*xi1);
            Jx3 = x(3)*(4*xi3-1) + 4*(x(6)*xi1 + x(5)*xi2);
            Jy1 = y(1)*(4*xi1-1) + 4*(y(4)*xi2 + y(6)*xi3);
            Jy2 = y(2)*(4*xi2-1) + 4*(y(5)*xi3 + y(4)*xi1);
            Jy3 = y(3)*(4*xi3-1) + 4*(y(6)*xi1 + y(5)*xi2);            
            
            J = [1,1,1; Jx1, Jx2, Jx3; Jy1, Jy2, Jy3];
        end
        
        function N = basis(~, in)
            % Returns a row vector of local shape functions    
            xi1 = in(1); xi2 = in(2);
            xi3 = 1 - xi1 - xi2;
            
            N(1) = xi3*(2*xi3-1);
            N(2) = xi1*(2*xi1-1);
            N(3) = xi2*(2*xi2-1);
            N(4) = 4*xi3*xi1;
            N(5) = 4*xi1*xi2;
            N(6) = 4*xi3*xi2;
          end

        function B = gradBasis(obj, in) 
            % Gradient of shape functions
            xi1 = in(1); xi2 = in(2);
            xi3 = 1 - xi1 - xi2;
            x = obj.nodes(:,1);
            y = obj.nodes(:,2);
            
            Dx4 = x(4) - 1/2*(x(1) + x(2));
            Dy4 = y(4) - 1/2*(y(1) + y(2));
            Dx5 = x(5) - 1/2*(x(2) + x(3));
            Dy5 = y(5) - 1/2*(y(2) + y(3));           
            Dx6 = x(6) - 1/2*(x(3) + x(1));
            Dy6 = y(6) - 1/2*(y(3) + y(1));                
            
            xx = @(i,j) obj.nodes(i,1) - obj.nodes(j,1);
            yy = @(i,j) obj.nodes(i,2) - obj.nodes(j,2);
            
            Jx21 = xx(2,1) + 4*(Dx4*(xi1-xi2) + (Dx5-Dx6)*xi3);
            Jx32 = xx(3,2) + 4*(Dx5*(xi2-xi3) + (Dx6-Dx4)*xi1);
            Jx13 = xx(1,3) + 4*(Dx6*(xi3-xi1) + (Dx4-Dx5)*xi2);
            Jy12 = yy(1,2) + 4*(Dy4*(xi2-xi1) + (Dy6-Dy5)*xi3);
            Jy23 = yy(2,3) + 4*(Dy5*(xi3-xi2) + (Dy4-Dy6)*xi1);
            Jy31 = yy(3,1) + 4*(Dy6*(xi1-xi3) + (Dy5-Dy4)*xi2);  
            
             J = 1/2*obj.detJ(in);
            
            B(:,1) = [(4*xi1-1)*Jy23, (4*xi1-1)*Jx32];
            B(:,2) = [(4*xi2-1)*Jy31, (4*xi2-1)*Jx13];   
            B(:,3) = [(4*xi3-1)*Jy12, (4*xi3-1)*Jx21];
            B(:,4) = [4*(xi2*Jy23+xi1*Jy31), 4*(xi2*Jx32+xi1*Jx13)];
            B(:,5) = [4*(xi3*Jy31+xi2*Jy12), 4*(xi3*Jx13+xi2*Jx21)]; 
            B(:,6) = [4*(xi1*Jy12+xi3*Jy23), 4*(xi1*Jx21+xi3*Jx32)];  
            
            B = 1/(2*J)*B;
        end
        
        function GN = localGradBasis(~, ~)
            error('Tri6:localGradBasis', 'Function not defined for the %s element, the B matrix is computed directly.', class(obj));
        end
    end
end