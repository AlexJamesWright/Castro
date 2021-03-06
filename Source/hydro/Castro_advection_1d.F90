module ctu_advection_module

  use bl_constants_module, only : ZERO, HALF, ONE, FOURTH

  use amrex_fort_module, only : rt => amrex_real
  implicit none

  private

  public umeth, consup

contains

! ::: ---------------------------------------------------------------
! ::: :: UMETH     Compute hyperbolic fluxes using unsplit second
! ::: ::            order Godunov integrator.
! ::: ::
! ::: :: inputs/outputs
! ::: :: q           => (const)  input state, primitives
! ::: :: qaux        => (const)  auxiliary hydro info
! ::: :: flatn       => (const)  flattening parameter
! ::: :: srcQ        => (const)  source for primitive variables
! ::: :: dx          => (const)  grid spacing in X direction
! ::: :: dt          => (const)  time stepsize
! ::: :: flux      <=  (modify) flux in X direction on X edges
! ::: ----------------------------------------------------------------

  subroutine umeth(q, q_lo, q_hi, &
                   flatn, &
                   qaux, qa_lo, qa_hi, &
                   srcQ, src_lo, src_hi, &
                   lo, hi, dx, dt, &
                   uout, uout_lo, uout_hi, &
                   flux, fd_lo, fd_hi, &
#ifdef RADIATION
                   rflux, rfd_lo, rfd_hi, &
#endif
                   q1, q1_lo, q1_hi, &
                   area1, area1_lo, area1_hi, &
                   vol, vol_lo, vol_hi, &
                   dloga, dloga_lo, dloga_hi, &
                   domlo, domhi)

    use meth_params_module, only : QVAR, NQ, NVAR, &
                                   QC, QFS, QFX, QGAMC, QU, QRHO, QTEMP, QPRES, QREINT, &
                                   NQAUX, NGDNV, &
                                   ppm_type, hybrid_riemann, &
                                   use_pslope, plm_iorder, ppm_temp_fix
    use riemann_module, only : cmpflx
    use trace_module, only : tracexy
#ifdef RADIATION
    use rad_params_module, only : ngroups
    use trace_ppm_rad_module, only : tracexy_ppm_rad
#else
    use trace_ppm_module, only : tracexy_ppm
#endif
#ifdef SHOCK_VAR
    use meth_params_module, only : USHK
#endif

    use amrex_fort_module, only : rt => amrex_real
    use advection_util_module, only : shock
    use eos_type_module, only : eos_t, eos_input_rt
    use eos_module, only : eos
    use network, only : nspec, naux
    use ppm_module, only : ppm_reconstruct, ppm_int_profile
    use slope_module, only : uslope, pslope
    use prob_params_module, only : dg

    implicit none

    integer, intent(in) :: lo(3), hi(3)
    integer, intent(in) :: domlo(3), domhi(3)
    integer, intent(in) :: dloga_lo(3), dloga_hi(3)
    integer, intent(in) :: q_lo(3), q_hi(3)
    integer, intent(in) :: qa_lo(3), qa_hi(3)
    integer, intent(in) :: src_lo(3), src_hi(3)
    integer, intent(in) :: uout_lo(3), uout_hi(3)
    integer, intent(in) :: fd_lo(3), fd_hi(3)
#ifdef RADIATION
    integer, intent(in) :: rfd_lo(3), rfd_hi(3)
#endif
    integer, intent(in) :: q1_lo(3), q1_hi(3)
    integer, intent(in) :: area1_lo(3), area1_hi(3)
    integer, intent(in) :: vol_lo(3), vol_hi(3)

    real(rt)        , intent(in) :: dx(3), dt
    real(rt)        , intent(in) :: q(   q_lo(1):q_hi(1),NQ)
    real(rt)        , intent(in) :: qaux(   qa_lo(1):qa_hi(1),NQAUX)
    real(rt)        , intent(in) :: flatn(   q_lo(1):q_hi(1))
    real(rt)        , intent(inout) :: uout(uout_lo(1):uout_hi(1),NVAR)
    real(rt)        , intent(inout) :: flux(fd_lo(1):fd_hi(1),NVAR)
#ifdef RADIATION
    real(rt)        , intent(inout) :: rflux(rfd_lo(1):rfd_hi(1),0:ngroups-1)
#endif
    real(rt)        , intent(in) :: srcQ(src_lo(1)  :src_hi(1),QVAR)
    real(rt)        , intent(inout) :: q1(q1_lo(1):q1_hi(1),NGDNV)
    real(rt)        , intent(in) :: dloga(dloga_lo(1):dloga_hi(1))
    real(rt)        , intent(in) :: area1(area1_lo(1):area1_hi(1))
    real(rt)        , intent(in) :: vol(vol_lo(1):vol_hi(1))

    real(rt)        , allocatable :: shk(:)

    integer :: i, n, iwave

    ! Left and right state arrays (edge centered, cell centered)
    real(rt)        , allocatable:: dq(:,:), qm(:,:), qp(:,:)

    integer :: qp_lo(3), qp_hi(3)
    integer :: shk_lo(3), shk_hi(3)
    integer :: I_lo(3), I_hi(3)

    real(rt), allocatable :: Ip(:,:,:)
    real(rt), allocatable :: Im(:,:,:)

    real(rt), allocatable :: Ip_src(:,:,:)
    real(rt), allocatable :: Im_src(:,:,:)

    ! gamma_c/1 on the interfaces
    real(rt), allocatable :: Ip_gc(:,:,:)
    real(rt), allocatable :: Im_gc(:,:,:)

    ! temporary interface values of the parabola
    real(rt), allocatable :: sxm(:), sxp(:)

    type(eos_t) :: eos_state

    qp_lo = lo - dg
    qp_hi = hi + 2*dg

    shk_lo = lo - dg
    shk_hi = hi + dg

    I_lo = lo - dg
    I_hi = hi + dg


    if (ppm_type > 0) then
       ! indices: (x, y, dimension, wave, variable)
       allocate(Ip(I_lo(1):I_hi(1), 3, NQ))
       allocate(Im(I_lo(1):I_hi(1), 3, NQ))

       allocate(Ip_src(I_lo(1):I_hi(1), 3, QVAR))
       allocate(Im_src(I_lo(1):I_hi(1), 3, QVAR))

       allocate(Ip_gc(I_lo(1):I_hi(1), 3, 1))
       allocate(Im_gc(I_lo(1):I_hi(1), 3, 1))

       allocate(sxm(q_lo(1):q_hi(1)))
       allocate(sxp(q_lo(1):q_hi(1)))
    endif

    allocate (shk(shk_lo(1):shk_hi(1)))


#ifdef SHOCK_VAR
    uout(lo(1):hi(1),USHK) = ZERO

    call shock(q, q_lo, q_hi, &
               shk, shk_lo, shk_hi, &
               lo, hi, dx)

    ! Store the shock data for future use in the burning step.
    do i = lo(1), hi(1)
       uout(i,USHK) = shk(i)
    enddo

    ! Discard it locally if we don't need it in the hydro update.
    if (hybrid_riemann /= 1) then
       shk(:) = ZERO
    endif
#else
    ! multidimensional shock detection -- this will be used to do the
    ! hybrid Riemann solver
    if (hybrid_riemann == 1) then
       call shock(q, q_lo, q_hi, &
                  shk, shk_lo, shk_hi, &
                  lo, hi, dx)
    else
       shk(:) = ZERO
    endif
#endif

    ! Work arrays to hold 3 planes of riemann state and conservative fluxes
    allocate ( qm(qp_lo(1):qp_hi(1),NQ))
    allocate ( qp(qp_lo(1):qp_hi(1),NQ))

    if (ppm_type == 0) then
       allocate(dq(q_lo(1):q_hi(1),NQ))

       if (plm_iorder == 1) then
          dq(lo(1)-1:hi(1)+1,1:NQ) = ZERO

       else
          ! piecewise linear slope
          call uslope(q, flatn, q_lo, q_hi, &
                      dq, dq, dq, q_lo, q_hi, &
                      lo(1), 0, hi(1), 0, 0, 0)

          if (use_pslope == 1) &
               call pslope(q, flatn, q_lo, q_hi, &
                           dq, dq, dq, q_lo, q_hi, &
                           srcQ, src_lo, src_hi, &
                           lo(1), 0, hi(1), 0, 0, 0, dx)

       endif

    else

       ! Compute Ip and Im -- this does the parabolic reconstruction,
       ! limiting, and returns the integral of each profile under each
       ! wave to each interface
       do n = 1, NQ
          call ppm_reconstruct(q(:,n), q_lo, q_hi, &
                               flatn, q_lo, q_hi, &
                               sxm, sxp, q_lo, q_hi, &
                               lo(1), 0, hi(1), 0, dx, 0, 0)

          call ppm_int_profile(q(:,n), q_lo, q_hi, &
                               q(:,QU), q_lo, q_hi, &
                               qaux(:,QC), qa_lo, qa_hi, &
                               sxm, sxp, q_lo, q_hi, &
                               Ip(:,:,n), Im(:,:,n), I_lo, I_hi, &
                               lo(1), 0, hi(1), 0, dx, dt, 0, 0)
       enddo

       ! temperature-based PPM -- if desired, take the Ip(T)/Im(T)
       ! constructed above and use the EOS to overwrite Ip(p)/Im(p)
       if (ppm_temp_fix == 1) then
          do i = lo(1)-1, hi(1)+1
             do iwave = 1, 3
                eos_state%rho   = Ip(i,iwave,QRHO)
                eos_state%T     = Ip(i,iwave,QTEMP)
                eos_state%xn(:) = Ip(i,iwave,QFS:QFS-1+nspec)
                eos_state%aux   = Ip(i,iwave,QFX:QFX-1+naux)

                call eos(eos_input_rt, eos_state)

                Ip(i,iwave,QPRES) = eos_state%p
                Ip(i,iwave,QREINT) = Ip(i,iwave,QRHO)*eos_state%e
                Ip_gc(i,iwave,1) = eos_state%gam1

                eos_state%rho   = Im(i,iwave,QRHO)
                eos_state%T     = Im(i,iwave,QTEMP)
                eos_state%xn(:) = Im(i,iwave,QFS:QFS-1+nspec)
                eos_state%aux   = Im(i,iwave,QFX:QFX-1+naux)

                call eos(eos_input_rt, eos_state)

                Im(i,iwave,QPRES) = eos_state%p
                Im(i,iwave,QREINT) = Im(i,iwave,QRHO)*eos_state%e
                Im_gc(i,iwave,1) = eos_state%gam1
             enddo
          enddo

       endif


       ! get an edge-based gam1 here if we didn't get it from the EOS
       ! call above (for ppm_temp_fix = 1)
       if (ppm_temp_fix /= 1) then
          call ppm_reconstruct(qaux(:,QGAMC), qa_lo, qa_hi, &
                               flatn, q_lo, q_hi, &
                               sxm, sxp, q_lo, q_hi, &
                               lo(1), 0, hi(1), 0, dx, 0, 0)

          call ppm_int_profile(qaux(:,QGAMC), qa_lo, qa_hi, &
                               q(:,QU), q_lo, q_hi, &
                               qaux(:,QC), qa_lo, qa_hi, &
                               sxm, sxp, q_lo, q_hi, &
                               Ip_gc(:,:,1), Im_gc(:,:,1), I_lo, I_hi, &
                               lo(1), 0, hi(1), 0, dx, dt, 0, 0)
       endif

       do n = 1, QVAR
          call ppm_reconstruct(srcQ(:,n), src_lo, src_hi, &
                               flatn, q_lo, q_hi, &
                               sxm, sxp, q_lo, q_hi, &
                               lo(1), 0, hi(1), 0, dx, 0, 0)

          call ppm_int_profile(srcQ(:,n), src_lo, src_hi, &
                               q(:,QU), q_lo, q_hi, &
                               qaux(:,QC), qa_lo, qa_hi, &
                               sxm, sxp, q_lo, q_hi, &
                               Ip_src(:,:,n), Im_src(:,:,n), I_lo, I_hi, &
                               lo(1), 0, hi(1), 0, dx, dt, 0, 0)
       enddo

       deallocate(sxm, sxp)
    endif

    ! Trace to edges
    if (ppm_type .gt. 0) then
#ifdef RADIATION
       call tracexy_ppm_rad(q, q_lo, q_hi, &
                            qaux, qa_lo, qa_hi, &
                            Ip, Im, Ip_src, Im_src, I_lo, I_hi, &
                            qm, qp, qm, qp, qp_lo, qp_hi, &
                            dloga, dloga_lo, dloga_hi, &
                            lo(1), 0, hi(1), 0, domlo, domhi, &
                            dx, dt, 0, 0)
#else
       call tracexy_ppm(q, q_lo, q_hi, &
                        qaux, qa_lo, qa_hi, &
                        Ip, Im, Ip_src, Im_src, Ip_gc, Im_gc, I_lo, I_hi, &
                        qm, qp, qm, qp, qp_lo, qp_hi, &
                        dloga, dloga_lo, dloga_hi, &
                        lo(1), 0, hi(1), 0, domlo, domhi, &
                        dx, dt, 0, 0)
#endif
    else
#ifdef RADIATION
       call bl_error("ppm_type <=0 is not supported in umeth with radiation")
#else

       call tracexy(q, q_lo, q_hi, &
                    qaux, qa_lo, qa_hi, &
                    dq, dq, q_lo, q_hi, &
                    qm, qp, qm, qp, qp_lo, qp_hi, &
                    dloga, dloga_lo, dloga_hi, &
                    srcQ, src_lo, src_hi, &
                    lo(1), 0, hi(1), 0, domlo, domhi, &
                    dx, dt, 0, 0)

       deallocate(dq)
#endif
    end if

    ! Solve Riemann problem, compute xflux from improved predicted states
    call cmpflx(qm, qp, qp_lo, qp_hi, &
                flux, fd_lo, fd_hi, &
                q1, q1_lo, q1_hi, &
#ifdef RADIATION
                rflux, rfd_lo,rfd_hi, &
#endif
                qaux, qa_lo, qa_hi, &
                shk, shk_lo, shk_hi, &
                1, lo(1), hi(1)+1, 0, 0, 0, 0, 0, &
                domlo, domhi)

    deallocate (qm,qp)

  end subroutine umeth

! :::
! ::: ------------------------------------------------------------------
! :::

  subroutine consup(uin, uin_lo, uin_hi, &
                    q, q_lo, q_hi, &
                    uout, uout_lo, uout_hi, &
                    update, updt_lo, updt_hi, &
                    flux, flux_lo, flux_hi, &
#ifdef RADIATION
                    Erin, Erin_lo, Erin_hi, &
                    Erout, Erout_lo, Erout_hi, &
                    rflux, rflux_lo, rflux_hi, &
                    nstep_fsp, &
#endif
                    q1, q1_lo, q1_hi, &
                    area, area_lo, area_hi, &
                    vol, vol_lo, vol_hi, &
                    div, lo, hi, dx, dt, &
                    mass_lost, xmom_lost, ymom_lost, zmom_lost, &
                    eden_lost, xang_lost, yang_lost, zang_lost, &
                    verbose)

    use meth_params_module, only : difmag, NVAR, URHO, UMX, UMY, UMZ, &
                                   UEDEN, UEINT, UTEMP, track_grid_losses, &
#ifdef RADIATION
                                   GDLAMS, GDERADS, &
                                   comoving, fspace_type, &
                                   GDU, GDPRES, &
#endif
                                   limit_fluxes_on_small_dens, NGDNV, GDPRES, NQ
    use advection_util_module, only : limit_hydro_fluxes_on_small_dens, normalize_species_fluxes, calc_pdivu
    use prob_params_module, only : domlo_level, domhi_level, center, coord_type
    use castro_util_module, only : position, linear_to_angular_momentum
    use amrinfo_module, only : amr_level
#ifdef RADIATION
    use rad_params_module, only : ngroups, nugroup, dlognu
    use radhydro_nd_module, only : advect_in_fspace
    use fluxlimiter_module, only : Edd_factor
#endif
#ifdef SHOCK_VAR
    use meth_params_module, only : USHK
#endif

    use amrex_fort_module, only : rt => amrex_real
    integer, intent(in) :: lo(3), hi(3)
    integer, intent(in) :: uin_lo(3), uin_hi(3)
    integer, intent(in) :: uout_lo(3), uout_hi(3)
    integer, intent(in) :: updt_lo(3), updt_hi(3)
    integer, intent(in) :: q1_lo(3), q1_hi(3)
    integer, intent(in) :: q_lo(3),  q_hi(3)
    integer, intent(in) :: flux_lo(3), flux_hi(3)
#ifdef RADIATION
    integer, intent(in) :: Erin_lo(3), Erin_hi(3)
    integer, intent(in) :: Erout_lo(3), Erout_hi(3)
    integer, intent(in) :: rflux_lo(3), rflux_hi(3)
    integer, intent(inout) :: nstep_fsp
#endif
    integer, intent(in) :: area_lo(3), area_hi(3)
    integer, intent(in) :: vol_lo(3),  vol_hi(3)
    integer, intent(in) :: verbose

    real(rt)        , intent(in) :: uin(uin_lo(1):uin_hi(1),NVAR)
    real(rt)        , intent(in) :: uout(uout_lo(1):uout_hi(1),NVAR)
    real(rt)        , intent(inout) :: update(updt_lo(1):updt_hi(1),NVAR)
    real(rt)        , intent(in) :: q1(q1_lo(1):q1_hi(1),NGDNV)
    real(rt)        , intent(in) :: q(q_lo(1):q_hi(1),NQ)
    real(rt)        , intent(inout) :: flux(flux_lo(1):flux_hi(1),NVAR)
#ifdef RADIATION
    real(rt)        , intent(in) :: Erin(Erin_lo(1):Erin_hi(1),0:ngroups-1)
    real(rt)        , intent(inout) :: Erout(Erout_lo(1):Erout_hi(1),0:ngroups-1)
    real(rt)        , intent(inout) :: rflux(rflux_lo(1):rflux_hi(1),0:ngroups-1)
#endif
    real(rt)        , intent(in) :: area( area_lo(1): area_hi(1))
    real(rt)        , intent(in) :: vol(vol_lo(1):vol_hi(1))
    real(rt)        , intent(in) :: div(lo(1):hi(1)+1)
    real(rt)        , intent(in) :: dx(3), dt
    real(rt)        , intent(inout) :: mass_lost, xmom_lost, ymom_lost, zmom_lost
    real(rt)        , intent(inout) :: eden_lost, xang_lost, yang_lost, zang_lost

    integer          :: i, j, k, n
    real(rt)         :: div1
    integer          :: domlo(3), domhi(3)
    real(rt)         :: loc(3), ang_mom(3)
#ifdef RADIATION
    integer :: g
    real(rt)         :: SrU, Up, SrE

    real(rt)        , dimension(0:ngroups-1) :: Erscale
    real(rt)        , dimension(0:ngroups-1) :: ustar, af
    real(rt)         :: Eddf, Eddflft, Eddfrgt, f1, f2, f1lft, f1rgt
    real(rt)         :: ux, divu, dudx, Egdc, lamc
    real(rt)         :: dpdx, dprdx, ek1, ek2, dek

    real(rt)         :: urho_new, umx_new1, umy_new1, umz_new1
    real(rt)         :: umx_new2, umy_new2, umz_new2
#endif
    real(rt)        , allocatable :: pdivu(:)

    allocate( pdivu(lo(1):hi(1)  ))

    call calc_pdivu([lo(1), 0, 0], [hi(1), 0, 0], &
                    q1, q1_lo, q1_hi, &
                    area, area_lo, area_hi, &
                    vol, vol_lo, vol_hi, &
                    dx, pdivu, lo, hi)

#ifdef RADIATION
    if (ngroups .gt. 1) then
       if (fspace_type .eq. 1) then
          Erscale = dlognu
       else
          Erscale = nugroup*dlognu
       end if
    end if
#endif

    do n = 1, NVAR
       if ( n == UTEMP ) then
          flux(lo(1):hi(1)+1,n) = ZERO
#ifdef SHOCK_VAR
       else if ( n == USHK) then
          flux(lo(1):hi(1)+1,n) = ZERO
#endif
       else if ( n == UMY ) then
          flux(lo(1):hi(1)+1,n) = ZERO
       else if ( n == UMZ ) then
          flux(lo(1):hi(1)+1,n) = ZERO
       else
          ! add the artifical viscosity
          do i = lo(1),hi(1)+1
             div1 = difmag*min(ZERO,div(i))
             flux(i,n) = flux(i,n) + dx(1)*div1*(uin(i,n) - uin(i-1,n))
          enddo
       endif
    enddo

    ! Limit the fluxes to avoid negative/small densities.

    if (limit_fluxes_on_small_dens .eq. 1) then
       call limit_hydro_fluxes_on_small_dens(uin, uin_lo, uin_hi, &
                                             q, q_lo, q_hi, &
                                             vol, vol_lo, vol_hi, &
                                             flux, flux_lo, flux_hi, &
                                             area, area_lo, area_hi, &
                                             lo, hi, dt, dx)
    endif

    ! Normalize the species fluxes.
    call normalize_species_fluxes(flux, flux_lo, flux_hi, lo, hi)

#ifdef RADIATION
    ! now do the radiation energy groups parts
    do g=0, ngroups-1
       do i = lo(1),hi(1)+1
          div1 = difmag*min(ZERO, div(i))
          rflux(i,g) = rflux(i,g) + dx(1)*div1*(Erin(i,g) - Erin(i-1,g))
       enddo
    enddo
#endif


    ! For hydro, we will create an update source term that is
    ! essentially the flux divergence.  This can be added with dt to
    ! get the update

    do n = 1, NVAR
       do i = lo(1), hi(1)
          update(i,n) = update(i,n) + ( flux(i,n) * area(i) - &
                                        flux(i+1,n) * area(i+1) ) / vol(i)

          ! Add p div(u) source term to (rho e)
          if (n == UEINT) then
             update(i,n) = update(i,n) - pdivu(i)
          endif

       enddo
    enddo

#ifndef RADIATION
    ! Add gradp term to momentum equation -- in 1-d this is not included in the
    ! flux
    do i = lo(1),hi(1)
       update(i,UMX) = update(i,UMX) - ( q1(i+1,GDPRES) - q1(i,GDPRES) ) / dx(1)
    enddo

#else

    ! radiation energy update.  For the moment, we actually update things
    ! fully here, instead of creating a source term for the update
    do g=0, ngroups-1
       do i = lo(1),hi(1)
          Erout(i,g) = Erin(i,g) + dt * (rflux(i,g) * area(i) - &
                                         rflux(i+1,g) * area(i+1) ) / vol(i)
       enddo
    end do


    ! Add gradp term to momentum equation -- this includes hydro and radiation terms
    ! Note: in 1-d, the pressure term is not included in the momentum flux
    do i = lo(1),hi(1)

       ! hydrodynamics contribution
       dpdx  = (  q1(i+1,GDPRES)- q1(i,GDPRES) ) / dx(1)
       update(i,UMX) = update(i,UMX) - dpdx

       ! radiation contribution -- this is sum{lambda E_r}
       dprdx = ZERO
       do g=0,ngroups-1
          lamc = HALF*(q1(i,GDLAMS+g) + q1(i+1,GDLAMS+g))
          dprdx = dprdx + lamc*(q1(i+1,GDERADS+g) - q1(i,GDERADS+g))/dx(1)
       end do

       ! we now want to compute the change in kinetic energy -- we
       ! base this off of uout, since that has the source terms in it.
       ! But note that this does not have the fluxes (since we are
       ! using update)
       urho_new = uout(i,URHO) + dt * update(i,URHO)

       ! this update includes the hydro fluxes and dpdr from hydro
       umx_new1 = uout(i,UMX) + dt * update(i,UMX)
       umy_new1 = uout(i,UMY) + dt * update(i,UMY)
       umz_new1 = uout(i,UMZ) + dt * update(i,UMZ)
       ek1 = (umx_new1**2 + umy_new1**2 + umz_new1**2)/(2.e0_rt*urho_new)

       ! now add the radiation pressure gradient
       update(i,UMX) = update(i,UMX) - dprdx
       umx_new2 = umx_new1 - dt * dprdx
       umy_new2 = umy_new1
       umz_new2 = umz_new1
       ek2 = (umx_new2**2 + umy_new2**2 + umz_new2**2)/(2.e0_rt*urho_new)

       dek = ek2 - ek1

       ! the update is a source / dt, so scale accordingly
       update(i,UEDEN) = update(i,UEDEN) + dek/dt

       if (.not. comoving) then ! mixed-frame (single group only)
          Erout(i,0) = Erout(i,0) - dek
       end if
    enddo

    ! Add radiation source term to rho*u, rhoE, and Er
    if (comoving) then
       do i = lo(1),hi(1)

          ux = HALF*(q1(i,GDU) + q1(i+1,GDU))

          divu = (q1(i+1,GDU)*area(i+1) - q1(i,GDU)*area(i))/vol(i)
          dudx = (q1(i+1,GDU) - q1(i,GDU))/dx(1)

          ! Note that for single group, fspace_type is always 1
          do g=0, ngroups-1

             lamc = HALF * (q1(i,GDLAMS+g) + q1(i+1,GDLAMS+g))
             Eddf = Edd_factor(lamc)
             f1 = (ONE - Eddf)*HALF
             f2 = (3.e0_rt*Eddf - ONE)*HALF
             af(g) = -(f1*divu + f2*dudx)

             if (fspace_type .eq. 1) then
                Eddflft = Edd_factor(q1(i,GDLAMS+g))
                f1lft = HALF * (ONE - Eddflft)
                Eddfrgt = Edd_factor(q1(i+1,GDLAMS+g))
                f1rgt = HALF * (ONE - Eddfrgt)

                Egdc = HALF*(q1(i,GDERADS+g) + q1(i+1,GDERADS+g))
                Erout(i,g) = Erout(i,g) + &
                     dt*ux*(f1rgt*q1(i+1,GDERADS+g) - f1lft*q1(i,GDERADS+g))/dx(1) &
                     - dt*f2*Egdc*dudx
             end if

          end do

          if (ngroups.gt.1) then
             ustar = Erout(i,:) / Erscale
             call advect_in_fspace(ustar, af, dt, nstep_fsp)
             Erout(i,:) = ustar * Erscale
          end if
       end do
    end if
#endif


    ! Scale the fluxes for the form we expect later in refluxing.

    do n = 1, NVAR
       do i = lo(1), hi(1)+1

          flux(i,n) = dt * area(i) * flux(i,n)

          ! Correct the momentum flux with the grad p part.
          if (coord_type .eq. 0 .and. n == UMX) then
             flux(i,n) = flux(i,n) + dt * area(i) * q1(i,GDPRES)
          endif

       enddo
    enddo

#ifdef RADIATION
    do g = 0, ngroups-1
       do i = lo(1), hi(1)+1
          rflux(i,g) = dt * area(i) * rflux(i,g)
       enddo
    enddo
#endif

    ! Add up some diagnostic quantities. Note that we are not dividing
    ! by the cell volume.

    if (track_grid_losses .eq. 1) then

       domlo = domlo_level(:,amr_level)
       domhi = domhi_level(:,amr_level)

       j = 0
       k = 0

       if (lo(1) .le. domlo(1) .and. hi(1) .ge. domlo(1)) then

          i = domlo(1)

          loc = position(i,j,k,ccx=.false.)

          mass_lost = mass_lost - flux(i,URHO)
          xmom_lost = xmom_lost - flux(i,UMX)
          ymom_lost = ymom_lost - flux(i,UMY)
          zmom_lost = zmom_lost - flux(i,UMZ)
          eden_lost = eden_lost - flux(i,UEDEN)

          ang_mom   = linear_to_angular_momentum(loc - center, flux(i,UMX:UMZ))
          xang_lost = xang_lost - ang_mom(1)
          yang_lost = yang_lost - ang_mom(2)
          zang_lost = zang_lost - ang_mom(3)

       endif

       if (lo(1) .le. domhi(1) .and. hi(1) .ge. domhi(1)) then

          i = domhi(1) + 1

          loc = position(i,j,k,ccx=.false.)

          mass_lost = mass_lost + flux(i,URHO)
          xmom_lost = xmom_lost + flux(i,UMX)
          ymom_lost = ymom_lost + flux(i,UMY)
          zmom_lost = zmom_lost + flux(i,UMZ)
          eden_lost = eden_lost + flux(i,UEDEN)

          ang_mom   = linear_to_angular_momentum(loc - center, flux(i,UMX:UMZ))
          xang_lost = xang_lost + ang_mom(1)
          yang_lost = yang_lost + ang_mom(2)
          zang_lost = zang_lost + ang_mom(3)

       endif

    endif

    deallocate(pdivu)

  end subroutine consup

end module ctu_advection_module
