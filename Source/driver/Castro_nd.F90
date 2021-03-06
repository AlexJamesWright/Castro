subroutine ca_network_init() bind(C, name="ca_network_init")

  use network, only: network_init
#ifdef REACTIONS
  use actual_rhs_module, only: actual_rhs_init
#endif

  call network_init()

#ifdef REACTIONS
  call actual_rhs_init()
#endif

end subroutine ca_network_init

subroutine ca_network_finalize() bind(C, name="ca_network_finalize")

  use network, only: network_finalize

  call network_finalize()

end subroutine ca_network_finalize


! :::
! ::: ----------------------------------------------------------------
! :::

subroutine ca_extern_init(name,namlen) bind(C, name="ca_extern_init")

  ! initialize the external runtime parameters in
  ! extern_probin_module

  use amrex_fort_module, only: rt => amrex_real

  integer, intent(in) :: namlen
  integer, intent(in) :: name(namlen)

  call runtime_init(name,namlen)

end subroutine ca_extern_init

! :::
! ::: ----------------------------------------------------------------
! :::

subroutine ca_get_num_spec(nspec_out) bind(C, name="ca_get_num_spec")

  use network, only: nspec
  use amrex_fort_module, only: rt => amrex_real

  implicit none

  integer, intent(out) :: nspec_out

  nspec_out = nspec

end subroutine ca_get_num_spec

! :::
! ::: ----------------------------------------------------------------
! :::

subroutine ca_get_num_aux(naux_out) bind(C, name="ca_get_num_aux")

  use network, only: naux
  use amrex_fort_module, only: rt => amrex_real

  implicit none

  integer, intent(out) :: naux_out

  naux_out = naux

end subroutine ca_get_num_aux

! :::
! ::: ----------------------------------------------------------------
! :::

subroutine ca_get_spec_names(spec_names,ispec,len) &
     bind(C, name="ca_get_spec_names")

  use network, only: nspec, short_spec_names
  use amrex_fort_module, only: rt => amrex_real

  implicit none

  integer, intent(in   ) :: ispec
  integer, intent(inout) :: len
  integer, intent(inout) :: spec_names(len)

  ! Local variables
  integer   :: i

  len = len_trim(short_spec_names(ispec+1))

  do i = 1,len
     spec_names(i) = ichar(short_spec_names(ispec+1)(i:i))
  end do

end subroutine ca_get_spec_names

! :::
! ::: ----------------------------------------------------------------
! :::

subroutine ca_get_spec_az(ispec,A,Z) bind(C, name="ca_get_spec_az")

  use network, only: nspec, aion, zion
  use amrex_fort_module, only: rt => amrex_real

  implicit none

  integer,  intent(in   ) :: ispec
  real(rt), intent(inout) :: A, Z

  ! C++ is 0-based indexing, so increment
  A = aion(ispec+1)
  Z = zion(ispec+1)

end subroutine ca_get_spec_az

! :::
! ::: ----------------------------------------------------------------
! :::

subroutine ca_get_aux_names(aux_names,iaux,len) &
     bind(C, name="ca_get_aux_names")

  use network, only: naux, short_aux_names
  use amrex_fort_module, only: rt => amrex_real

  implicit none

  integer, intent(in   ) :: iaux
  integer, intent(inout) :: len
  integer, intent(inout) :: aux_names(len)

  ! Local variables
  integer   :: i

  len = len_trim(short_aux_names(iaux+1))

  do i = 1,len
     aux_names(i) = ichar(short_aux_names(iaux+1)(i:i))
  end do

end subroutine ca_get_aux_names

! :::
! ::: ----------------------------------------------------------------
! :::

subroutine ca_get_qvar(qvar_in) bind(C, name="ca_get_qvar")

  use meth_params_module, only: QVAR

  implicit none

  integer, intent(inout) :: qvar_in

  qvar_in = QVAR

end subroutine ca_get_qvar

subroutine ca_get_nq(nq_in) bind(C, name="ca_get_nq")

  use meth_params_module, only: NQ

  implicit none

  integer, intent(inout) :: nq_in

  nq_in = NQ

end subroutine ca_get_nq

subroutine ca_get_nqaux(nqaux_in) bind(C, name="ca_get_nqaux")

  use meth_params_module, only: NQAUX

  implicit none

  integer, intent(inout) :: nqaux_in

  nqaux_in = NQAUX

end subroutine ca_get_nqaux

! :::
! ::: ----------------------------------------------------------------
! :::

subroutine ca_set_amr_info(level_in, iteration_in, ncycle_in, time_in, dt_in) &
     bind(C, name="ca_set_amr_info")

  use amrinfo_module, only: amr_level, amr_iteration, amr_ncycle, amr_time, amr_dt
  use amrex_fort_module, only: rt => amrex_real

  implicit none

  integer,  intent(in) :: level_in, iteration_in, ncycle_in
  real(rt), intent(in) :: time_in, dt_in

  if (level_in .ge. 0) then
     amr_level = level_in
  endif

  if (iteration_in .ge. 0) then
     amr_iteration = iteration_in
  endif

  if (ncycle_in .ge. 0) then
     amr_ncycle = ncycle_in
  endif

  if (time_in .ge. 0.0) then
     amr_time = time_in
  endif

  if (dt_in .ge. 0.0) then
     amr_dt = dt_in
  endif


end subroutine ca_set_amr_info

! :::
! ::: ----------------------------------------------------------------
! :::

subroutine ca_get_method_params(nGrowHyp) bind(C, name="ca_get_method_params")

  ! Passing data from f90 back to C++

  use meth_params_module, only: NHYP
  use amrex_fort_module, only: rt => amrex_real

  implicit none

  integer, intent(out) :: ngrowHyp

  nGrowHyp = NHYP

end subroutine ca_get_method_params

! :::
! ::: ----------------------------------------------------------------
! :::

subroutine allocate_outflow_data(np,nc) &
     bind(C, name="allocate_outflow_data")

  use meth_params_module, only: outflow_data_old, outflow_data_new, outflow_data_allocated
  use amrex_fort_module, only: rt => amrex_real

  implicit none

  integer, intent(in) :: np,nc

  if (.not. outflow_data_allocated) then
     allocate(outflow_data_old(nc,np))
     allocate(outflow_data_new(nc,np))
  end if

  outflow_data_allocated = .true.

end subroutine allocate_outflow_data

! :::
! ::: ----------------------------------------------------------------
! :::
subroutine set_old_outflow_data(radial,time,np,nc) &
     bind(C, name="set_old_outflow_data")

  ! Passing data from C++ to f90

  use meth_params_module, only: outflow_data_old, outflow_data_old_time
  use amrex_fort_module, only: rt => amrex_real

  implicit none

  real(rt), intent(in) :: radial(nc,np)
  real(rt), intent(in) :: time
  integer,  intent(in) :: np,nc

  ! Do this so the routine has the right size
  deallocate(outflow_data_old)
  allocate(outflow_data_old(nc,np))

  outflow_data_old(1:nc,1:np) = radial(1:nc,1:np)

  outflow_data_old_time = time

end subroutine set_old_outflow_data

! :::
! ::: ----------------------------------------------------------------
! :::
subroutine set_new_outflow_data(radial,time,np,nc) &
     bind(C, name="set_new_outflow_data")

  ! Passing data from C++ to f90

  use meth_params_module, only: outflow_data_new, outflow_data_new_time
  use amrex_fort_module, only: rt => amrex_real

  implicit none

  real(rt), intent(in) :: radial(nc,np)
  real(rt), intent(in) :: time
  integer,  intent(in) :: np,nc

  ! Do this so the routine has the right size
  deallocate(outflow_data_new)
  allocate(outflow_data_new(nc,np))

  outflow_data_new(1:nc,1:np) = radial(1:nc,1:np)

  outflow_data_new_time = time

end subroutine set_new_outflow_data

! :::
! ::: ----------------------------------------------------------------
! :::
subroutine swap_outflow_data() bind(C, name="swap_outflow_data")

  use meth_params_module, only: outflow_data_new, outflow_data_new_time, &
                                outflow_data_old, outflow_data_old_time
  use amrex_fort_module, only: rt => amrex_real

  implicit none

  integer :: np, nc

  nc = size(outflow_data_new,dim=1)
  np = size(outflow_data_new,dim=2)

  if (size(outflow_data_old,dim=2) .ne. size(outflow_data_new,dim=2)) then
     ! Do this so the routine has the right size
     deallocate(outflow_data_old)
     allocate(outflow_data_old(nc,np))
  end if

  if (size(outflow_data_old,dim=2) .ne. size(outflow_data_new,dim=2)) then
     print *,'size of old and new dont match in swap_outflow_data '
     call bl_error("Error:: Castro_nd.f90 :: swap_outflow_data")
  end if

  outflow_data_old(1:nc,1:np) = outflow_data_new(1:nc,1:np)

  if (outflow_data_new_time .ge. 0.e0_rt) &
       outflow_data_old_time = outflow_data_new_time
  outflow_data_new_time = -1.e0_rt

end subroutine swap_outflow_data

! :::
! ::: ----------------------------------------------------------------
! :::

subroutine ca_set_method_params(dm, Density, Xmom, &
#ifdef HYBRID_MOMENTUM
                                Rmom, &
#endif
                                Eden, Eint, Temp, &
                                FirstAdv, FirstSpec, FirstAux, numadv, &
#ifdef SHOCK_VAR
                                Shock, &
#endif
#ifdef RADIATION
                                ngroups_in, &
#endif
                                gravity_type_in, gravity_type_len) &
                                bind(C, name="ca_set_method_params")

  use meth_params_module
  use network, only : nspec, naux
  use eos_module, only: eos_init
  use eos_type_module, only: eos_get_small_dens, eos_get_small_temp
  use bl_constants_module, only : ZERO, ONE
  use amrex_fort_module, only: rt => amrex_real
#ifdef RADIATION
  use rad_params_module, only: ngroups
#endif

  implicit none

  integer, intent(in) :: dm
  integer, intent(in) :: Density, Xmom, Eden, Eint, Temp, &
                         FirstAdv, FirstSpec, FirstAux
  integer, intent(in) :: numadv
#ifdef SHOCK_VAR
  integer, intent(in) :: Shock
#endif
  integer, intent(in) :: gravity_type_len
  integer, intent(in) :: gravity_type_in(gravity_type_len)
#ifdef RADIATION
  integer, intent(in) :: ngroups_in
#endif
#ifdef HYBRID_MOMENTUM
  integer, intent(in) :: Rmom
#endif

  integer :: iadv, ispec

  integer :: QLAST
  integer :: NTHERM, QTHERM

  integer :: i
  integer :: ioproc

#ifdef RADIATION
  ngroups = ngroups_in
#endif

  !---------------------------------------------------------------------
  ! set integer keys to index states
  !---------------------------------------------------------------------
  call ca_set_godunov_indices()

  call ca_set_conserved_indices( &
#ifdef HYBRID_MOMENTUM
                                Rmom, Rmom+1, Rmom+2, &
#endif
#ifdef SHOCK_VAR
                                Shock, &
#endif
                                Density ,Xmom, Xmom+1, Xmom+2, &
                                Eden, Eint, Temp, &
                                FirstAdv, FirstSpec, FirstAux &
                                )

  call ca_set_auxiliary_indices()

  call ca_set_primitive_indices()

  ! easy indexing for the passively advected quantities.  This
  ! lets us loop over all groups (advected, species, aux)
  ! in a single loop.
  allocate(qpass_map(QVAR))
  allocate(upass_map(NVAR))

  ! Transverse velocities

  if (dm == 1) then
     upass_map(1) = UMY
     qpass_map(1) = QV

     upass_map(2) = UMZ
     qpass_map(2) = QW

     npassive = 2

  else if (dm == 2) then
     upass_map(1) = UMZ
     qpass_map(1) = QW

     npassive = 1
  else
     npassive = 0
  endif

  do iadv = 1, nadv
     upass_map(npassive + iadv) = UFA + iadv - 1
     qpass_map(npassive + iadv) = QFA + iadv - 1
  enddo
  npassive = npassive + nadv

  if (QFS > -1) then
     do ispec = 1, nspec+naux
        upass_map(npassive + ispec) = UFS + ispec - 1
        qpass_map(npassive + ispec) = QFS + ispec - 1
     enddo
     npassive = npassive + nspec + naux
  endif


#ifdef RADIATION
  QRADHI = QRAD + ngroups - 1
#endif

  !---------------------------------------------------------------------
  ! other initializations
  !---------------------------------------------------------------------

  ! This is a routine which links to the C++ ParallelDescriptor class

  call bl_pd_is_ioproc(ioproc)

  allocate(character(len=gravity_type_len) :: gravity_type)

  do i = 1, gravity_type_len
     gravity_type(i:i) = char(gravity_type_in(i))
  enddo

#ifdef ROTATION
  rot_vec = ZERO
  rot_vec(rot_axis) = ONE
#endif


  !---------------------------------------------------------------------
  ! safety checks
  !---------------------------------------------------------------------

  if (small_dens <= 0.e0_rt) then
     if (ioproc == 1) then
        call bl_warning("Warning:: small_dens has not been set, defaulting to 1.e-200_rt.")
     endif
     small_dens = 1.e-200_rt
  endif

  if (small_temp <= 0.e0_rt) then
     if (ioproc == 1) then
        call bl_warning("Warning:: small_temp has not been set, defaulting to 1.e-200_rt.")
     endif
     small_temp = 1.e-200_rt
  endif

  if (small_pres <= 0.e0_rt) then
     small_pres = 1.e-200_rt
  endif

  if (small_ener <= 0.e0_rt) then
     small_ener = 1.e-200_rt
  endif

  ! Note that the EOS may modify our choices because of its
  ! internal limitations, so the small_dens and small_temp
  ! may be modified coming back out of this routine.

  call eos_init(small_dens=small_dens, small_temp=small_temp)

  ! Update device variables

  !$acc update &
  !$acc device(NVAR) &
  !$acc device(NQ) &
  !$acc device(URHO, UMX, UMY, UMZ, UMR, UML, UMP, UEDEN, UEINT, UTEMP, UFA, UFS, UFX) &
  !$acc device(USHK) &
  !$acc device(QVAR) &
  !$acc device(QRHO, QU, QV, QW, QPRES, QREINT, QTEMP, QGAME) &
  !$acc device(QFA, QFS, QFX) &
  !$acc device(NQAUX, QGAMC, QC, QDPDR, QDPDE) &
#ifdef RADIATION
  !$acc device(QGAMCG, QCG, QLAMS) &
#endif
  !$acc device(small_dens, small_temp)

end subroutine ca_set_method_params


subroutine ca_init_godunov_indices() bind(C, name="ca_init_godunov_indices")

  use meth_params_module, only: GDRHO, GDU, GDV, GDW, GDPRES, GDGAME, NGDNV, &
#ifdef RADIATION
                                GDLAMS, GDERADS, &
#endif
                                QU, QV, QW

  use amrex_fort_module, only: rt => amrex_real
#ifdef RADIATION
  use rad_params_module, only : ngroups
#endif

  implicit none

  NGDNV = 6
#if RADIATION
  NGDNV = NGDNV + 2*ngroups
#endif

  GDRHO = 1
  GDU = 2
  GDV = 3
  GDW = 4
  GDPRES = 5
  GDGAME = 6
#ifdef RADIATION
  GDLAMS = GDGAME+1            ! starting index for rad lambda
  GDERADS = GDLAMS + ngroups   ! starting index for rad energy
#endif

  ! sanity check
  if ((QU /= GDU) .or. (QV /= GDV) .or. (QW /= GDW)) then
     call bl_error("ERROR: velocity components for godunov and primitive state are not aligned")
  endif

end subroutine ca_init_godunov_indices

! :::
! ::: ----------------------------------------------------------------
! :::

subroutine ca_set_problem_params(dm,physbc_lo_in,physbc_hi_in,&
                                 Interior_in, Inflow_in, Outflow_in, &
                                 Symmetry_in, SlipWall_in, NoSlipWall_in, &
                                 coord_type_in, &
                                 problo_in, probhi_in, center_in) &
                                 bind(C, name="ca_set_problem_params")

  ! Passing data from C++ into f90

  use bl_constants_module, only: ZERO
  use prob_params_module
  use meth_params_module, only: UMX, UMY, UMZ
#ifdef ROTATION
  use meth_params_module, only: rot_axis
#endif
  use amrex_fort_module, only: rt => amrex_real

  implicit none

  integer,  intent(in) :: dm
  integer,  intent(in) :: physbc_lo_in(dm),physbc_hi_in(dm)
  integer,  intent(in) :: Interior_in, Inflow_in, Outflow_in, Symmetry_in, SlipWall_in, NoSlipWall_in
  integer,  intent(in) :: coord_type_in
  real(rt), intent(in) :: problo_in(dm), probhi_in(dm), center_in(dm)

  dim = dm

  physbc_lo(1:dm) = physbc_lo_in(1:dm)
  physbc_hi(1:dm) = physbc_hi_in(1:dm)

  Interior   = Interior_in
  Inflow     = Inflow_in
  Outflow    = Outflow_in
  Symmetry   = Symmetry_in
  SlipWall   = SlipWall_in
  NoSlipWall = NoSlipWall_in

  coord_type = coord_type_in

  problo = ZERO
  probhi = ZERO
  center = ZERO

  problo(1:dm) = problo_in(1:dm)
  probhi(1:dm) = probhi_in(1:dm)
  center(1:dm) = center_in(1:dm)

  dg(:) = 1

  if (dim .lt. 2) then
     dg(2) = 0
  endif

  if (dim .lt. 3) then
     dg(3) = 0
  endif

#ifdef ROTATION
  if (coord_type == 1) then
     rot_axis = 2
  endif
#endif


  ! sanity check on our allocations
  if (UMZ > MAX_MOM_INDEX) then
     call bl_error("ERROR: not enough space in comp in mom_flux_has_p")
  endif

  ! keep track of which components of the momentum flux have pressure
  if (dim == 1 .or. (dim == 2 .and. coord_type == 1)) then
     mom_flux_has_p(1)%comp(UMX) = .false.
  else
     mom_flux_has_p(1)%comp(UMX) = .true.
  endif
  mom_flux_has_p(1)%comp(UMY) = .false.
  mom_flux_has_p(1)%comp(UMZ) = .false.

  mom_flux_has_p(2)%comp(UMX) = .false.
  mom_flux_has_p(2)%comp(UMY) = .true.
  mom_flux_has_p(2)%comp(UMZ) = .false.

  mom_flux_has_p(3)%comp(UMX) = .false.
  mom_flux_has_p(3)%comp(UMY) = .false.
  mom_flux_has_p(3)%comp(UMZ) = .true.


end subroutine ca_set_problem_params

! :::
! ::: ----------------------------------------------------------------
! :::

subroutine ca_set_grid_info(max_level_in, dx_level_in, domlo_in, domhi_in, &
                            ref_ratio_in, n_error_buf_in, blocking_factor_in) &
                            bind(C, name="ca_set_grid_info")

  use prob_params_module, only: max_level, dx_level, domlo_level, domhi_level, n_error_buf, ref_ratio, blocking_factor
  use amrex_fort_module, only: rt => amrex_real

  implicit none

  integer,  intent(in) :: max_level_in
  real(rt), intent(in) :: dx_level_in(3*(max_level_in+1))
  integer,  intent(in) :: domlo_in(3*(max_level_in+1)), domhi_in(3*(max_level_in+1))
  integer,  intent(in) :: ref_ratio_in(3*(max_level_in+1))
  integer,  intent(in) :: n_error_buf_in(0:max_level_in)
  integer,  intent(in) :: blocking_factor_in(0:max_level_in)

  integer :: lev, dir

  ! Sometimes this routine can get called multiple
  ! times upon initialization; in this case, just to
  ! be safe, we'll deallocate and start again.

  if (allocated(dx_level)) then
     deallocate(dx_level)
  endif
  if (allocated(domlo_level)) then
     deallocate(domlo_level)
  endif
  if (allocated(domhi_level)) then
     deallocate(domhi_level)
  endif

  if (allocated(ref_ratio)) then
     deallocate(ref_ratio)
  endif
  if (allocated(n_error_buf)) then
     deallocate(n_error_buf)
  endif
  if (allocated(blocking_factor)) then
     deallocate(blocking_factor)
  endif

  max_level = max_level_in

  allocate(dx_level(1:3, 0:max_level))
  allocate(domlo_level(1:3, 0:max_level))
  allocate(domhi_level(1:3, 0:max_level))
  allocate(ref_ratio(1:3, 0:max_level))
  allocate(n_error_buf(0:max_level))
  allocate(blocking_factor(0:max_level))

  do lev = 0, max_level
     do dir = 1, 3
        dx_level(dir,lev) = dx_level_in(3*lev + dir)
        domlo_level(dir,lev) = domlo_in(3*lev + dir)
        domhi_level(dir,lev) = domhi_in(3*lev + dir)
        ref_ratio(dir,lev) = ref_ratio_in(3*lev + dir)
     enddo
     n_error_buf(lev) = n_error_buf_in(lev)
     blocking_factor(lev) = blocking_factor_in(lev)
  enddo

end subroutine ca_set_grid_info


! :::
! ::: ----------------------------------------------------------------
! :::

subroutine ca_get_tagging_params(name, namlen) &
     bind(C, name="ca_get_tagging_params")

  ! Initialize the tagging parameters

  use tagging_module
  use amrex_fort_module, only: rt => amrex_real

  integer, intent(in) :: namlen
  integer, intent(in) :: name(namlen)

  integer :: un, i, status

  integer, parameter :: maxlen = 256
  character (len=maxlen) :: probin

  namelist /tagging/ &
       denerr,     dengrad,   max_denerr_lev,   max_dengrad_lev, &
       enterr,     entgrad,   max_enterr_lev,   max_entgrad_lev, &
       velerr,     velgrad,   max_velerr_lev,   max_velgrad_lev, &
       presserr, pressgrad, max_presserr_lev, max_pressgrad_lev, &
       temperr,   tempgrad,  max_temperr_lev,  max_tempgrad_lev, &
       raderr,     radgrad,   max_raderr_lev,   max_radgrad_lev

  ! Set namelist defaults
  denerr = 1.e20_rt
  dengrad = 1.e20_rt
  max_denerr_lev = 10
  max_dengrad_lev = 10

  enterr = 1.e20_rt
  entgrad = 1.e20_rt
  max_enterr_lev = -1
  max_entgrad_lev = -1

  presserr = 1.e20_rt
  pressgrad = 1.e20_rt
  max_presserr_lev = -1
  max_pressgrad_lev = -1

  velerr  = 1.e20_rt
  velgrad = 1.e20_rt
  max_velerr_lev = -1
  max_velgrad_lev = -1

  temperr  = 1.e20_rt
  tempgrad = 1.e20_rt
  max_temperr_lev = -1
  max_tempgrad_lev = -1

  raderr  = 1.e20_rt
  radgrad = 1.e20_rt
  max_raderr_lev = -1
  max_radgrad_lev = -1

  ! create the filename
  if (namlen > maxlen) then
     call bl_error('probin file name too long')
  endif

  do i = 1, namlen
     probin(i:i) = char(name(i))
  end do

  ! read in the namelist
  un = 9
  open (unit=un, file=probin(1:namlen), form='formatted', status='old')
  read (unit=un, nml=tagging, iostat=status)

  if (status < 0) then
     ! the namelist does not exist, so we just go with the defaults
     continue

  else if (status > 0) then
     ! some problem in the namelist
     call bl_error('ERROR: problem in the tagging namelist')
  endif

  close (unit=un)

end subroutine ca_get_tagging_params

#ifdef SPONGE
! :::
! ::: ----------------------------------------------------------------
! :::

subroutine ca_get_sponge_params(name, namlen) bind(C, name="ca_get_sponge_params")

  ! Initialize the sponge parameters

  use sponge_module
  use amrex_fort_module, only: rt => amrex_real

  integer, intent(in) :: namlen
  integer, intent(in) :: name(namlen)

  integer :: un, i, status

  integer, parameter :: maxlen = 256
  character (len=maxlen) :: probin

  real(rt) :: sponge_target_x_velocity
  real(rt) :: sponge_target_y_velocity
  real(rt) :: sponge_target_z_velocity

  namelist /sponge/ &
       sponge_lower_factor, sponge_upper_factor, &
       sponge_lower_radius, sponge_upper_radius, &
       sponge_lower_density, sponge_upper_density, &
       sponge_lower_pressure, sponge_upper_pressure, &
       sponge_target_x_velocity, &
       sponge_target_y_velocity, &
       sponge_target_z_velocity, &
       sponge_timescale

  ! Set namelist defaults

  sponge_lower_factor = 0.e0_rt
  sponge_upper_factor = 1.e0_rt

  sponge_lower_radius = -1.e0_rt
  sponge_upper_radius = -1.e0_rt

  sponge_lower_density = -1.e0_rt
  sponge_upper_density = -1.e0_rt

  sponge_lower_pressure = -1.e0_rt
  sponge_upper_pressure = -1.e0_rt

  sponge_target_x_velocity = 0.e0_rt
  sponge_target_y_velocity = 0.e0_rt
  sponge_target_z_velocity = 0.e0_rt

  sponge_timescale    = -1.e0_rt

  ! create the filename
  if (namlen > maxlen) then
     call bl_error('probin file name too long')
  endif

  do i = 1, namlen
     probin(i:i) = char(name(i))
  end do

  ! read in the namelist
  un = 9
  open (unit=un, file=probin(1:namlen), form='formatted', status='old')
  read (unit=un, nml=sponge, iostat=status)

  if (status < 0) then
     ! the namelist does not exist, so we just go with the defaults
     continue

  else if (status > 0) then
     ! some problem in the namelist
     call bl_error('ERROR: problem in the sponge namelist')
  endif

  close (unit=un)

  sponge_target_velocity = [sponge_target_x_velocity, &
                            sponge_target_y_velocity, &
                            sponge_target_z_velocity]

  ! Sanity check

  if (sponge_lower_factor < 0.e0_rt .or. sponge_lower_factor > 1.e0_rt) then
     call bl_error('ERROR: sponge_lower_factor cannot be outside of [0, 1].')
  endif

  if (sponge_upper_factor < 0.e0_rt .or. sponge_upper_factor > 1.e0_rt) then
     call bl_error('ERROR: sponge_upper_factor cannot be outside of [0, 1].')
  endif

end subroutine ca_get_sponge_params
#endif

#ifdef POINTMASS
! :::
! ::: ----------------------------------------------------------------
! :::

subroutine set_pointmass(pointmass_in) bind(C, name='set_pointmass')

  use meth_params_module, only: point_mass
  use amrex_fort_module, only: rt => amrex_real

  implicit none

  real(rt), intent(in) :: pointmass_in

  point_mass = pointmass_in

end subroutine set_pointmass
#endif
