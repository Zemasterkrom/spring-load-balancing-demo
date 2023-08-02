import {Component, OnInit} from '@angular/core';
import {VideoGame} from '../shared/types/videogame.type';
import {filter, mergeMap, Observable} from 'rxjs';
import {MatDialog, MatDialogRef} from '@angular/material/dialog';
import {DialogComponent} from '../shared/dialog/dialog.component';
import {VideoGameService} from '../shared/services/video-game.service';
import {Router} from '@angular/router';

@Component({
    selector: 'video-games',
    templateUrl: './video-games.component.html',
    styleUrls: ['./video-games.component.css']
})
export class VideoGamesComponent implements OnInit {

    // Liste des jeux vidéo
    private _videoGames: VideoGame[];

    // Status (pour un jeu vidéo/carte descriptive) actif ou inactif du formulaire
    private _dialogStatus: string;

    // Dialogue associé à une carte descriptique d'un jeu vidéo
    private _videoGameDialog: MatDialogRef<DialogComponent, VideoGame> | undefined;

    // Jeu vidéo qui a essayé d'être ajouté (conservé en mémoire pour corriger les erreurs)
    private _triedVideoGame: VideoGame | undefined;

    /**
     * Constructeur de la liste des jeux vidéo
     * @param _router Permet de gérer les routes et redirections
     * @param _videoGamesService Service des jeux vidéo
     * @param _dialog Dialogue à construire pour un jeu vidéo
     */
    constructor(private _router: Router, private _videoGamesService: VideoGameService, private _dialog: MatDialog) {
        this._videoGames = [];
        this._dialogStatus = 'inactive';
        this._router.routeReuseStrategy.shouldReuseRoute = () => false;
        this._router.onSameUrlNavigation = 'reload';
    }

    /**
     * Retourner la liste des jeux vidéo
     */
    get videoGames(): VideoGame[] {
        return this._videoGames;
    }

    /**
     * Retourner le status du formulaire affiché
     */
    get dialogStatus(): string {
        return this._dialogStatus;
    }

    /**
     * Obtenir tous les jeux vidéo et les afficher
     */
    ngOnInit(): void {
        this._videoGamesService
            .fetchAll()
            .subscribe((vg: VideoGame[]) => this._videoGames = vg);
    }

    /**
     * Supprimer un jeu vidéo
     * @param vg Jeu vidéo
     */
    delete(vg: VideoGame): void {
        this._videoGamesService
            .delete(vg.id as any)
            .subscribe((id: any) => this._videoGames = this._videoGames.filter((vg: VideoGame) => vg.id !== id));
    }

    /**
     * Afficher le formulaire pour un jeu vidéo
     * @param newData Jeu vidéo à afficher (ou données supplémentaires en cas d'erreur)
     */
    showDialog(newData?: any): void {

        this._dialogStatus = 'active';

        this._videoGameDialog = this._dialog.open(DialogComponent, {
            width: '500px',
            disableClose: false,
            data: newData ? newData : {}
        });

        this._videoGameDialog.afterClosed()
            .pipe(
                filter((vg: VideoGame | undefined) => !!vg),
                mergeMap((vg: VideoGame | undefined) => this._add(vg))
            )
            .subscribe({
                next: () => this._router.navigate(['/video-games/all']),
                error: (err) => this.showDialog(this._videoGamesService.modifyResponseForError(this._triedVideoGame ? this._triedVideoGame : {} as VideoGame, err.status)),
                complete: () => this._dialogStatus = 'inactive'
            });
    }

    /**
     * Ajouter un jeu vidéo
     * @param vg Jeu vidéo
     */
    private _add(vg: VideoGame | undefined): Observable<VideoGame> {
        this._triedVideoGame = vg;
        return this._videoGamesService.create(vg as VideoGame);
    }
}
