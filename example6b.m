% A transient heat transfer example
%
% Syntax:
%   example6b
%   example6b('PropertyName', PropertyValue)
%
% Description:
%   example6 solves a simple transient heat conduction problem, with the
%   default settings.
%
%   example6a('PropertyName', PropertyValue) allows the user to customize
%   the behavior of this example using the property pairs listed below.
%
% Example6a Property Descriptions
%
% N
%   scalar
% 
%    The number of elements in the x and y directions, the default is 32.
%
% Element
%   {'Quad4'} | 'Tri3' | 'Tri6'
%
%   Specifies the type of element for the mesh
%
% Method
%   {'normal'} | 'alt'
%
%   Inidicates the type of sparse matrix assembly to utilize, the 'alt'
%   method is the index method that is faster for large matrices.

function example6b(varargin)

% Import the mFEM library
import mFEM.*;

% Set the default options and apply the user defined options
opt.n = 32;
opt.element = 'Quad4';
opt.method = 'normal';
opt = gather_user_options(opt,varargin{:});

% Create a FEmesh object, add the single element, and initialize it
mesh = FEmesh();
mesh.grid(opt.element,0,1,0,1,opt.n,opt.n);
mesh.init();

% Label the boundaries
mesh.add_boundary(1); % essential boundaries (all)

% Build the system
sys = System(mesh);
sys.add_constant('D', 1 / (2*pi^2));   % thermal conductivity
sys.add_matrix('M', 'N''*N');
sys.add_matrix('K', 'B''*D*B');

% Build the matrices
M = sys.assemble('M');
K = sys.assemble('K');

% Define dof indices for the essential dofs and non-essential dofs
non = mesh.get_dof(1,'ne'); 
ess = mesh.get_dof(1);      

% Initialize the temperatures
T_exact = @(x,y,t) exp(-t)*sin(pi*x).*sin(pi*y);
nodes = mesh.get_nodes();
T = T_exact(nodes(:,1),nodes(:,2),0);

% Collect the node positions for applying the essential boundary conditions
x = nodes(:,1);
y = nodes(:,2);

% Plot the initial condition
figure; hold on;
mesh.plot(T);
title('t = 0');
xlabel('x');
ylabel('y');
cbar = colorbar;
set(get(cbar,'YLabel'),'String','Temperature');

% Numerical constants
theta = 0.5;                % numerical intergration parameter
dt = 0.1;                   % time-step

% Compute residual for non-essential boundaries, the mass matrix does not
% contribute because the dT/dt = 0 on the essential boundaries. This
% problem also does not have a force term.
R(:,1) = - K(non,ess)*T(ess);

% Use a general time integration scheme
K_hat = M(non,non) + theta*dt*K(non,non);
f_K   = M(non,non) - (1-theta)*dt*K(non,non);

% Perform 10 time-steps
for t = dt:dt:1;

    % Compute the force componenet using previous time step T
    f_hat = dt*R + f_K*T(non);

    % Solve for non-essential boundaries
    T(non) = K_hat\f_hat;
    
    % Set values for the essential boundary conditions the next time step 
    T(ess) = T_exact(x(ess), y(ess), t);

    % Plot the results
    pause(0.25);
    mesh.plot(T);
    title(['t = ', num2str(t)]);
end

% Clean up
delete(mesh);
