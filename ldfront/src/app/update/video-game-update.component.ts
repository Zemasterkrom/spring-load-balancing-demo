import {Component, OnInit} from '@angular/core';
import {VideoGame} from '../shared/types/videogame.type';
import {MatDialog, MatDialogRef} from '@angular/material/dialog';
import {DialogComponent} from '../shared/dialog/dialog.component';
import {ActivatedRoute, Router} from '@angular/router';
import {filter, map, mergeMap, Observable} from 'rxjs';
import {VideoGameService} from '../shared/services/video-game.service';

@Component({
    selector: 'nwt-update',
    templateUrl: './video-game-update.component.html'
})
export class VideoGameUpdateComponent implements OnInit {
    // Dialogue du jeu vidéo
    private _videoGameDialog: MatDialogRef<DialogComponent, VideoGame> | undefined;

    // Jeu vidéo mémorisé pour réutilisation en cas d'erreur
    private _triedVideoGame: VideoGame | undefined;

    // Identifiant mémorisé du jeu vidéo
    private _id: string;

    /**
     * Constructeur du formulaire de mise à jour d'un jeu vidéo
     * @param _route Route actuelle pour récupérer le paramètre nécessaire (identifiant du jeu)
     * @param _router Permet de gérer les routes et les redirections
     * @param _videoGamesService Service des jeux vidéo
     * @param _dialog Dialogue Material Design Angular à construire
     */
    constructor(private _route: ActivatedRoute, private _router: Router, private _videoGamesService: VideoGameService, private _dialog: MatDialog) {
        this._id = "";
    }

    /**
     * Récupérer le paramète (identifiant du jeu) dans la route
     */
    ngOnInit(): void {
        this._route.params
            .pipe(
                map((params: any) => params.id),
                mergeMap((id: string) => {
                    this.setVideoGameId(id);
                    return this._videoGamesService.fetchOne(id);
                })
            )
            .subscribe({
                next: (vg: VideoGame) => {
                    this.showDialog(vg)
                },
                error: () => {
                    this._router.navigate(['/video-games/all'])
                }
            });
    }

    /**
     * Afficher le formulaire de mise à jour
     * @param vg Jeu vidéo à mettre à jour contenant les données
     */
    private showDialog(vg: any): void {
        if (!vg) this._router.navigate(['/video-games/all']);
        vg.updateMode = true;

        this._videoGameDialog = this._dialog.open(DialogComponent, {
            width: '500px',
            disableClose: true,
            data: vg ? vg : {}
        });

        this._videoGameDialog.afterClosed()
            .pipe(
                filter((vg: VideoGame | undefined) => !!vg),
                map((vg: VideoGame | undefined) => {
                    delete vg?.id;
                    return {id: this._id, newVG: vg};
                }),
                mergeMap((vg: { id: string, newVG: any }) => this._update(vg.id, vg.newVG))
            )
            .subscribe({
                    error: (err) => this.showDialog(this._videoGamesService.modifyResponseForError(this._triedVideoGame ? this._triedVideoGame : {} as VideoGame, err.status)),
                    complete: () => this._router.navigate(['/video-games/all'])
                }
            );
    }

    /**
     * Mettre à jour le jeu vidéo et le mémoriser en cas d'erreur pour réafficher les données
     * @param id Identifiant (nom ou ID numérique) du jeu vidéo
     * @param vg Jeu vidéo contenant les données mises à jour
     */
    private _update(id: string, vg: VideoGame): Observable<any> {
        this._triedVideoGame = vg;
        return this._videoGamesService.update(id, vg);
    }

    /**
     * Mettre à jour l'identifiant pour le mémoriser (recherche dans la base de données)
     * @param id Identifiant du jeu vidéo (nom ou ID numérique)
     */
    private setVideoGameId(id: string) {
        this._id = id;
    }
}
